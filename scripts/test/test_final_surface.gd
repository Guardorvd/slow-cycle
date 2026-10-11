extends SceneTree
const Source = preload("res://scripts/test/final_surface_route_source.gd")
const Deformer = preload("res://scripts/world/region/road_terrain_deformer.gd")
const Surface = preload("res://scripts/world/region/final_surface.gd")
const Slice = preload("res://scripts/world/final_surface_slice.gd")
const Route = preload("res://scripts/world/region/certified_road_route.gd")
const Plan = preload("res://scripts/world/region/road_synthesis_plan.gd")
const Oracle = preload("res://scripts/test/road_synthesis_oracle.gd")
const Planner = preload("res://scripts/world/region/route_planner.gd")
const Context = preload("res://scripts/world/region/environment_context.gd")
const Biome = preload("res://scripts/world/region/biome_field.gd")
const Ride = preload("res://scripts/world/region/rideability_field.gd")
const Renderer = preload("res://scripts/world/region/final_surface_tile_renderer.gd")
var failures: Array = []
var assertions := 0
var report: Dictionary = {}
var group := "all"

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String, detail: Variant = null) -> void:
	assertions += 1
	if not condition:
		failures.append({"message":message,"detail":str(detail)})
		if failures.size()<=20:
			print("R7_ASSERT_FAIL ",message," ",detail)

func run() -> void:
	var mode := "cache"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source="):
			mode = arg.substr(9)
		if arg.begins_with("--group="):
			group = arg.substr(8)
	var source: Dictionary = Source.build(mode)
	check(source.is_valid,"route source",source.get("reason_code"))
	if not source.is_valid:
		finish()
		return
	var deformer0: int=Time.get_ticks_usec()
	var deformer: Dictionary = Deformer.create(source.route,source.field)
	var deformer_ms: float=(Time.get_ticks_usec()-deformer0)/1000.0
	check(deformer.is_valid,"deformer",[deformer.reason_code,deformer.get("detail",{})])
	if not deformer.is_valid:
		finish()
		return
	var surface: RefCounted = Surface.create(source.terrain,source.field,deformer.deformer).surface
	var data: Dictionary = source.route.get_data()
	report = {"source":mode,"group":group,"upstream_ms":source.upstream_ms,"route_digest":source.route.route_digest(),"plan_signature":data.plan_signature,"fixture_equal":source.fixture_equal}
	report["upstream_stages_ms"]=source.upstream_stages_ms
	report["deformer_ms"]=deformer_ms
	report["cache_dependency_key"]=source.key
	report["route_payload_sha256"]=Route.sha(source.route.to_bytes())
	if mode=="live":
		check(source.fixture_equal,"authenticated fixture equals actual live extract")
	if group in ["all","contracts"]:
		_contracts(source,surface)
		_index_parity(source,surface)
	if group in ["all","handoff"]:
		_handoff(source)
	if group in ["contracts","handoff"]:
		finish()
		return
	for p: Dictionary in data.pieces:
		var d: Dictionary = p.design
		for k in range(d.s.size()):
			for lateral: float in [-2.55,-1.8,0.0,1.8,2.55]:
				var x: float = d.x[k]-d.tz[k]*lateral
				var z: float = d.z[k]+d.tx[k]*lateral
				var sample: Dictionary = surface.sample_surface(x,z)
				check(sample.is_valid,"real surface valid",[p.id,k,lateral,sample])
				if sample.is_valid:
					var tolerance: float = 0.01
					for ref: Dictionary in p.intent.crossings:
						if d.s[k]>=ref.wet_s0-35 and d.s[k]<=ref.wet_s1+35:
							tolerance = 0.35
					check(absf(sample.height_m-(d.y[k]-lateral*tan(deg_to_rad(d.bank[k]))))<=tolerance,"road plane / approved R7-F1 cap",[p.id,k,lateral,sample.height_m,d.y[k]])
	if not failures.is_empty():
		finish()
		return
	_surface_samples(source,surface)
	_intent_stations(source,surface)
	_channel_samples(source,surface)
	if not failures.is_empty():
		finish()
		return
	# Warm the viewport's lazily created World3D before lifecycle measurement.
	var bootstrap := Node3D.new()
	root.add_child(bootstrap)
	var warm_space: PhysicsDirectSpaceState3D=bootstrap.get_world_3d().direct_space_state
	bootstrap.queue_free()
	await process_frame
	await process_frame
	bootstrap=null
	warm_space=null
	var objects_before: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var slice := Slice.new()
	root.add_child(slice)
	var built: Dictionary = slice.build(surface,source.hydrology,source.route)
	check(built.is_valid,"mesh build",built.get("reason_code"))
	if built.is_valid:
		print("R7_MESH ",JSON.stringify(slice.metrics))
		report["mesh"] = slice.metrics.duplicate()
		var poses: Dictionary=slice.get_route_poses()
		var exported: Dictionary={}
		for direction: String in ["forward","reverse"]:
			var pose: Dictionary=poses[direction]
			var h: Dictionary=surface.sample_surface(pose.position.x,pose.position.z)
			check(h.is_valid and h.kind=="ROAD" and absf(h.height_m-pose.position.y)<=0.01,"R8 endpoint pose lies on final road",direction)
			check(pose.direction.is_finite() and absf(pose.direction.length()-1.0)<0.00001,"R8 endpoint direction finite and unit",direction)
			exported[direction]={"position":[pose.position.x,pose.position.y,pose.position.z],"direction":[pose.direction.x,pose.direction.y,pose.direction.z]}
		report["r8_poses"]=exported
		_mesh_audit(slice,surface)
		await physics_frame
		await physics_frame
		if group in ["all","collision"]:
			_collision(source,surface,slice.get_world_3d().direct_space_state)
			_boundary_rays(slice,surface,slice.get_world_3d().direct_space_state)
	slice.queue_free()
	await process_frame
	await process_frame
	slice = null
	report["release_object_delta"] = int(Performance.get_monitor(Performance.OBJECT_COUNT))-objects_before
	check(report.release_object_delta==0,"slice create/release zero object delta",report.release_object_delta)
	finish()

func finish() -> void:
	report.merge({"assertions":assertions,"failures":failures.size(),"details":failures,"complete":true},true)
	print("R7_RESULT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _contracts(source: Dictionary,surface: RefCounted) -> void:
	var data: Dictionary = source.route.get_data()
	var changed: Dictionary = data.duplicate(true)
	changed.pieces[0].design.y[0]+=1.0
	check(Route.from_bytes(var_to_bytes(changed)).reason_code=="ERR_R7_ROUTE_DIGEST","negative altered design exact reason")
	changed=data.duplicate(true)
	changed.pieces.pop_back()
	check(Route.from_bytes(var_to_bytes(changed)).reason_code=="ERR_R7_ROUTE_PIECE_MISSING","negative missing piece exact reason")
	changed=data.duplicate(true)
	changed.pieces[0].intent.status="UNSUPPORTED"
	check(Route.from_bytes(var_to_bytes(changed)).reason_code=="ERR_R7_INTENT_INVALID","negative invalid intent exact reason")
	changed=data.duplicate(true)
	changed.plan_signature="wrong"
	check(Route.from_bytes(var_to_bytes(changed)).reason_code=="ERR_R7_ROUTE_DIGEST","negative signature exact reason")
	changed=data.duplicate(true)
	changed.pieces[0].intent={}
	check(Route.from_bytes(var_to_bytes(changed)).reason_code=="ERR_R7_ROUTE_PIECE_MISSING","negative missing intent exact reason")
	check(surface.sample_height(NAN,0).reason_code=="ERR_TERRAIN_NONFINITE_INPUT","nonfinite height")
	check(surface.sample_gradient(NAN,0).reason_code=="ERR_TERRAIN_NONFINITE_INPUT","nonfinite gradient")
	check(surface.sample_height(-1,0).reason_code=="ERR_TERRAIN_OUT_OF_DOMAIN","out of domain")
	check(surface.sample_fine_grid(0,0,0,1).reason_code=="ERR_TERRAIN_GRID_SHAPE","grid shape")
	check(Renderer.tile_arrays(surface,9,9).reason_code=="ERR_TERRAIN_OUT_OF_DOMAIN","renderer rejects invalid first vertex with exact reason")
	var path := "user://r7/negative_fixture.bin"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(var_to_bytes({"key":"wrong","spec":data.spec,"payload":source.route.to_bytes(),"sha":"wrong"}))
	file.close()
	check(Source.read_cache(path,source.key,data.spec).reason_code=="ERR_R7_CACHE_STALE","negative cache key exact reason")
	file=FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(var_to_bytes({"key":source.key,"spec":data.spec,"payload":source.route.to_bytes(),"sha":"wrong"}))
	file.close()
	check(Source.read_cache(path,source.key,data.spec).reason_code=="ERR_R7_CACHE_STALE","negative tampered fixture exact reason")
	DirAccess.remove_absolute(path)
	var fake: RefCounted=Route.new()
	fake._data=data.duplicate(true)
	fake._data.header.hydrology_signature="wrong"
	check(Deformer.create(fake,source.field).reason_code=="ERR_R7_SIGNATURE_MISMATCH","negative upstream signature exact reason")
	fake._data=data.duplicate(true)
	fake._data.header.region_signature="wrong"
	check(Deformer.create(fake,source.field).reason_code=="ERR_R7_SIGNATURE_MISMATCH","negative region signature exact reason")
	fake._data=data.duplicate(true)
	fake._data.pieces[-1].design.support[0]=2
	check(Deformer.create(fake,source.field).reason_code=="ERR_R7_BRIDGE_UNSUPPORTED","negative bridge exact reason")
	fake._data=data.duplicate(true)
	fake._data.pieces[0].intent.stations.delta_l[0]+=0.02
	check(Deformer.create(fake,source.field).reason_code=="ERR_R7_INTENT_MISMATCH","negative intent delta exact reason")
	var real: Dictionary=Deformer.create(source.route,source.field)
	check(real.is_valid,"negative probe real deformer creation")
	if real.is_valid:
		var deform: RefCounted=real.deformer
		for seg: Dictionary in deform._segments:
			if seg.id=="move:3:2-3":
				seg.patch.y0+=1.0
				var point: Vector2=(seg.a+seg.b)/2
				check(deform._candidate(seg,point,source.natural.sample_height(point.x,point.y).height_m).reason_code=="ERR_R7_PATCH_MISMATCH","negative connector plane exact reason")
				break
		var crossing: Dictionary=data.crossings[1]
		var point: Vector2=_at(data.pieces[0].design,crossing.s_m,0)
		var h: float=source.natural.sample_height(point.x,point.y).height_m
		for seg: Dictionary in deform._segments:
			var c: Dictionary=deform._candidate(seg,point,h)
			if c.get("plane",false):
				seg.d=seg.d.duplicate(true)
				seg.d.y[seg.k]+=1.0
				seg.d.y[seg.k+1]+=1.0
				seg.profile={"delta":PackedFloat64Array(),"step":0.5}
				deform._query_index.clear()
				deform._index[Vector2i(int(point.x/16),int(point.y/16))]=[deform._segments.find(seg)]
				check(deform.evaluate(point.x,point.y,h).reason_code=="ERR_R7_FORD_CHANNEL","negative crown above water exact reason")
				break
	var synthetic := Deformer.new()
	var limits := {"tie_max_m":12.0,"cut_max_m":3.0,"fill_max_m":2.0}
	for k in range(2):
		var design := {"s":PackedFloat64Array([0,16]),"y":PackedFloat64Array([1+k,1+k]),"grade":PackedFloat64Array([0,0]),"bank":PackedFloat64Array([0,0]),"width":PackedFloat64Array([4,4])}
		var seg := {"id":"synthetic:%d"%k,"k":0,"d":design,"profile":{"delta":PackedFloat64Array(),"step":0.5},"a":Vector2(0,8) if k==0 else Vector2(8,0),"b":Vector2(16,8) if k==0 else Vector2(8,16),"n0":Vector2(0,1) if k==0 else Vector2(-1,0),"n1":Vector2(0,1) if k==0 else Vector2(-1,0),"shoulder":0.0,"limits":limits,"patch":{},"reach":15.0,"first":true,"last":true}
		design["x"]=PackedFloat64Array([seg.a.x,seg.b.x])
		design["z"]=PackedFloat64Array([seg.a.y,seg.b.y])
		design["tx"]=PackedFloat64Array([seg.n0.y,seg.n1.y])
		design["tz"]=PackedFloat64Array([-seg.n0.x,-seg.n1.x])
		synthetic._segments.append(seg)
	synthetic._index[Vector2i.ZERO]=[0,1]
	check(synthetic.evaluate(8,8,0).reason_code=="ERR_R7_OWNER_CONFLICT","crossing planes reject exact reason")
	synthetic._index[Vector2i.ZERO]=[0]
	check(synthetic.evaluate(8,8,0).height_m==1.0,"one authoritative plane")
	check(absf(synthetic.evaluate(8,11,0).height_m-0.5)<0.001,"daylight envelope constructs the side slope")
	check(synthetic.evaluate(8,13,0).height_m==0.0,"daylight envelope returns natural exactly")
	synthetic._segments.append(synthetic._segments[0].duplicate(true))
	synthetic._segments[-1].id="synthetic:same"
	synthetic._index[Vector2i.ZERO]=[0,2]
	var forward: Dictionary=synthetic.evaluate(8,8,0)
	synthetic._index[Vector2i.ZERO]=[2,0]
	check(forward.height_m==synthetic.evaluate(8,8,0).height_m,"composition input order independent")
	synthetic._index[Vector2i(0,1)]=[0]
	check(synthetic.evaluate(8,22.5,100).reason_code=="ERR_R7_TIE_UNRESOLVED","unresolved tie rejects exact reason")
	var parallel:=Deformer.new()
	for i in range(2):
		var seg: Dictionary=synthetic._segments[0].duplicate(true)
		seg.id="parallel:%d"%i
		seg.a=Vector2(0,8+6*i)
		seg.b=Vector2(16,8+6*i)
		seg.d.z=PackedFloat64Array([seg.a.y,seg.b.y])
		seg.d.y=PackedFloat64Array([2,2] if i==0 else [-1,-1])
		parallel._segments.append(seg)
	parallel._index[Vector2i.ZERO]=[0,1]
	check(parallel.evaluate(8,11,0).reason_code=="ERR_R7_OWNER_CONFLICT","contradictory envelopes outside both planes reject")
	synthetic._index[Vector2i.ZERO]=[0]
	check(synthetic.evaluate(8,8,-2).reason_code=="ERR_R7_INTENT_MISMATCH","actual class fill violation rejects")

func _handoff(source: Dictionary) -> void:
	var data: Dictionary = source.route.get_data()
	var graph: RefCounted = source.graph
	if graph==null:
		graph=Planner.plan(source.region,source.terrain,source.hydrology).graph
	check(data.header.graph_signature==graph.signature(),"actual R5 graph signature")
	for edge: Dictionary in data.edges:
		check(edge.status=="READY" and edge.reasons.is_empty(),"selected edge READY without reasons",edge.edge_id)
	check(data.movements.size()==2,"two certified movements")
	for movement: Dictionary in data.movements:
		check(movement.status=="READY","movement READY",movement)
	var context: RefCounted = Context.create(source.region,source.terrain,source.hydrology).context
	var ride: RefCounted = Ride.create(context,Biome.create(context).field).field
	var total: float = 0.0
	var previous: RefCounted
	var ids: Array = []
	var digests: Dictionary = {}
	var barrier_count := 0
	for p: Dictionary in data.pieces:
		var path: RefCounted = Plan.export_path(p.design,false)
		digests[p.id]=Route.sha(Plan.export_bytes(path))
		check(Oracle.path_checks(path,p.info.route_class,p.info.kind=="MOVEMENT").failures.is_empty(),"independent R6 path contract",p.id)
		if previous!=null:
			check(previous.points[-1].distance_to(path.points[0])<=0.001,"piece seam <=1mm",p.id)
		previous=path
		total+=path.cumulative_distances[-1]
		var incident: Array = [int(p.id.split(":")[1])] if p.info.kind!="MOVEMENT" else [int(p.id.split(":")[2].split("-")[0]),int(p.id.split(":")[2].split("-")[1])]
		for k in range(path.points.size()):
			var point: Vector3 = path.points[k]
			var clearance: float = -INF
			for edge: int in incident:
				clearance=maxf(clearance,Oracle.band_clearance(graph.get_corridor(edge),0,0,point.x,point.z))
			check(clearance>=path.road_widths[k]/2,"edges and connector band containment",[p.id,k,clearance])
			for side: float in [-1.0,1.0]:
				var lateral: float = side*path.road_widths[k]/2
				var sample: Dictionary = ride.sample(p.design.x[k]-p.design.tz[k]*lateral,p.design.z[k]+p.design.tx[k]*lateral)
				check(sample.is_valid and not sample.blocked,"both road edges barrier valid/unblocked",[p.id,k,side])
				barrier_count+=1
		var water: Dictionary = Oracle.channel_hits(path,source.hydrology)
		check(water.bodies.is_empty(),"no unplanned body water",p.id)
		for hit: Dictionary in water.hits:
			ids.append(hit.channel_id)
	check(ids==[7,20,21],"channel identity and travel order",ids)
	check(absf(total-1118.5)<0.1,"accepted route length",total)
	report["piece_digests"]=digests
	report["barrier_samples"]=barrier_count
	report["route_length_m"]=total

func _index_parity(source: Dictionary,surface: RefCounted) -> void:
	var deform: RefCounted=surface._deformer
	var index: Dictionary=deform._query_index
	var count:=0
	for cell: Vector2i in deform._fine:
		for offset: Vector2 in [Vector2.ZERO,Vector2(16,0),Vector2(0,16),Vector2(16,16),Vector2(8,8)]:
			var point:=Vector2(cell)*16+offset
			var h: float=source.natural.sample_height(point.x,point.y).height_m
			var fast: Dictionary=deform.evaluate(point.x,point.y,h)
			deform._query_index={}
			var reference: Dictionary=deform.evaluate(point.x,point.y,h)
			deform._query_index=index
			check(var_to_bytes(fast)==var_to_bytes(reference),"conservative quad index equals original station search",point)
			count+=1
	report["index_parity_samples"]=count

func _at(d: Dictionary,s: float,t: float) -> Vector2:
	var k: int = clampi(d.s.bsearch(s)-1,0,d.s.size()-2)
	var u: float = (s-d.s[k])/(d.s[k+1]-d.s[k])
	return Vector2(lerpf(d.x[k],d.x[k+1],u)-t*lerpf(d.tz[k],d.tz[k+1],u),lerpf(d.z[k],d.z[k+1],u)+t*lerpf(d.tx[k],d.tx[k+1],u))

func _surface_samples(source: Dictionary,surface: RefCounted) -> void:
	var signature := PackedByteArray()
	var wet_channels: Dictionary = {}
	for p: Dictionary in source.route.get_data().pieces:
		var d: Dictionary=p.design
		for lateral: float in [-2.55,-1.8,0,1.8,2.55]:
			var previous: float = NAN
			for i in range(int(ceil(d.s[-1]/0.25))+1):
				var s: float=minf(i*0.25,d.s[-1])
				var point: Vector2 = _at(d,s,lateral)
				var sample: Dictionary=surface.sample_surface(point.x,point.y)
				check(sample.is_valid,"continuous surface samples valid",[p.id,s,lateral,sample.get("reason_code")])
				if not sample.is_valid:
					continue
				if is_finite(previous):
					check(absf(sample.height_m-previous)<=tan(deg_to_rad(5.0))*0.25+0.005,"continuous route both directions / class grade",[p.id,s,lateral,sample.height_m-previous])
				previous=sample.height_m
				var natural_height: float=source.natural.sample_height(point.x,point.y).height_m
				check(sample.height_m-natural_height<=p.intent.limits.fill_max_m+0.001 and natural_height-sample.height_m<=p.intent.limits.cut_max_m+0.001,"actual class cut/fill across road and shoulder",[p.id,s,lateral,sample.height_m-natural_height])
				signature.append_array(var_to_bytes(sample.height_m))
				var water: Dictionary=source.field.sample_water(point.x,point.y)
				if water.is_water:
					wet_channels[water.id]=true
					var h: float=source.natural.sample_height(point.x,point.y).height_m
					check(sample.height_m-h<=0.101,"actual bed filling bound",[p.id,s,lateral,sample.height_m-h])
					check(water.water_surface_m-sample.height_m>=0.02 and water.water_surface_m-sample.height_m<0.35,"actual ford clearance and depth",[p.id,s,lateral,water.water_surface_m-sample.height_m])
	check(wet_channels.size()==3 and wet_channels.has(7) and wet_channels.has(20) and wet_channels.has(21),"three actual fords covered")
	for piece: Dictionary in source.route.get_data().pieces:
		for i in range(int(ceil(piece.design.s[-1]/4))+1):
			for lateral: float in [-16.0,16.0]:
				var point: Vector2=_at(piece.design,minf(i*4,piece.design.s[-1]),lateral)
				var f: Dictionary=surface.sample_height(point.x,point.y)
				var h: Dictionary=source.natural.sample_height(point.x,point.y)
				check(f.is_valid and h.is_valid and var_to_bytes(f.height_m)==var_to_bytes(h.height_m),"outside construction footprint natural bitwise",[piece.id,i,lateral])
	for j in range(0,257,8):
		for i in range(0,257,8):
			if not surface.is_fine_cell(i,j):
				check(surface.sample_height(i*16,j*16).height_m==source.natural.sample_height(i*16,j*16).height_m,"outside footprint unchanged bitwise",[i,j])
	report["surface_signature"]=Route.sha(signature)

func _mesh_audit(slice: Node3D,surface: RefCounted) -> void:
	var geometry_hashes: Array=[]
	var boundaries: Dictionary = {}
	var missing_edges := 0
	var face_mismatch := 0
	for tile: Dictionary in slice.tiles:
		var vertices: PackedVector3Array=tile.arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array=tile.arrays[Mesh.ARRAY_INDEX]
		var normals: PackedVector3Array=tile.arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array=tile.arrays[Mesh.ARRAY_TEX_UV]
		geometry_hashes.append(Route.sha(var_to_bytes([tile.origin_x_m,tile.origin_z_m,vertices,indices,normals])))
		var edges: Dictionary={}
		var next_road:=0
		var next_terrain:=0
		for k in range(0,indices.size(),3):
			var centre: Vector3=(vertices[indices[k]]+vertices[indices[k+1]]+vertices[indices[k+2]])/3.0
			var layer: int=surface._collision_layer(centre.x+tile.origin_x_m,centre.z+tile.origin_z_m)
			for q in range(3):
				var a: int=indices[k+q]
				var b: int=indices[k+(q+1)%3]
				var key: int=mini(a,b)*(vertices.size()+1)+maxi(a,b)
				edges[key]=edges.get(key,0)+1
				var faces: PackedVector3Array=tile.faces.road if layer==2 else tile.faces.terrain
				var expected: int=next_road if layer==2 else next_terrain
				if expected+q>=faces.size() or faces[expected+q]!=vertices[a]:
					face_mismatch+=1
			if layer==2: next_road+=3
			else: next_terrain+=3
		check(next_road==tile.faces.road.size() and next_terrain==tile.faces.terrain.size(),"exactly one collider per render triangle")
		for layer: int in tile.shapes:
			check(tile.shapes[layer].get_faces()==(tile.faces.road if layer==2 else tile.faces.terrain),"registered shape faces equal rendered geometry",layer)
		for key: int in edges:
			var a: int=key/(vertices.size()+1)
			var b: int=key%(vertices.size()+1)
			var va: Vector3=vertices[a]
			var vb: Vector3=vertices[b]
			var boundary: bool=(va.x==vb.x and va.x in [0.0,512.0]) or (va.z==vb.z and va.z in [0.0,512.0])
			if edges[key]!=(1 if boundary else 2): missing_edges+=1
			if edges[key]!=(1 if boundary else 2) and missing_edges<=12:
				print("R7_OPEN_EDGE ",va+Vector3(tile.origin_x_m,0,tile.origin_z_m)," -> ",vb+Vector3(tile.origin_x_m,0,tile.origin_z_m)," count=",edges[key])
		for k in range(vertices.size()):
			var v: Vector3=vertices[k]
			check(v.is_finite() and normals[k].is_finite() and uv[k].is_finite(),"mesh finite geometry/normal/material attributes")
			if v.x==0 or v.x==512 or v.z==0 or v.z==512:
				var key := Vector2(v.x+tile.origin_x_m,v.z+tile.origin_z_m)
				if boundaries.has(key):
					check(boundaries[key]==[v.y,normals[k]],"tile boundary heights/normals bitwise",key)
				boundaries[key]=[v.y,normals[k]]
	check(missing_edges==0,"conforming 0.5/1/16 m mesh no interior open/T edges",missing_edges)
	check(face_mismatch==0,"render/collision vertex faces bitwise",face_mismatch)
	report["open_edges"]=missing_edges
	report["collision_face_mismatch"]=face_mismatch
	report["mesh_signatures"]=geometry_hashes

func _channel_samples(source: Dictionary,surface: RefCounted) -> void:
	var samples:=0
	var changes:=0
	for crossing: Dictionary in source.route.get_data().crossings:
		check(crossing.support=="FORD","all three crossings retain FORD support",crossing.channel_id)
		var channel: Dictionary=source.hydrology.get_channel(crossing.channel_id)
		for k in range(channel.x_cm.size()-1):
			var a:=Vector2(channel.x_cm[k],channel.z_cm[k])/100.0
			var b:=Vector2(channel.x_cm[k+1],channel.z_cm[k+1])/100.0
			if minf(a.distance_to(Vector2(crossing.r6_x,crossing.r6_z)),b.distance_to(Vector2(crossing.r6_x,crossing.r6_z)))>24: continue
			var divisions: int=maxi(1,int(ceil(a.distance_to(b)/0.25)))
			for i in range(divisions+1):
				var point: Vector2=a.lerp(b,float(i)/divisions)
				var water: Dictionary=source.field.sample_water(point.x,point.y)
				if not water.is_water: continue
				var h: float=source.natural.sample_height(point.x,point.y).height_m
				var f: Dictionary=surface.sample_surface(point.x,point.y)
				check(f.is_valid,"channel centre remains valid",[crossing.channel_id,point])
				if not f.is_valid: continue
				check(f.height_m<=h+0.101 and f.height_m<water.water_surface_m,"channel has no artificial blockage",[crossing.channel_id,point,f.height_m-h])
				check(f.height_m>=h-0.051,"channel bed band along actual channel centre",[crossing.channel_id,point,f.height_m-h])
				if f.height_m!=h: changes+=1
				samples+=1
	check(samples>0,"actual channel transects sampled")
	report["channel_centre_samples"]=samples
	report["channel_changed_samples"]=changes

func _intent_stations(source: Dictionary,surface: RefCounted) -> void:
	var daylight_samples:=0
	for piece: Dictionary in source.route.get_data().pieces:
		var d: Dictionary=piece.design
		var st: Dictionary=piece.intent.stations
		for i in range(st.s.size()):
			var in_ford_window:=false
			for crossing: Dictionary in piece.intent.crossings:
				if st.s[i]>=crossing.wet_s0-35 and st.s[i]<=crossing.wet_s1+35: in_ford_window=true
			var half: float=st.width[i]/2.0+(0.75 if piece.info.kind=="MOVEMENT" else piece.intent.limits.shoulder_m)
			for sign: float in [-1.0,1.0]:
				var point: Vector2=_at(d,st.s[i],half*sign)
				var h: float=source.natural.sample_height(point.x,point.y).height_m
				var f: Dictionary=surface.sample_surface(point.x,point.y)
				check(f.is_valid,"intent shoulder realization valid",[piece.id,i,sign])
				if not f.is_valid: continue
				if piece.info.kind!="MOVEMENT" and not in_ford_window:
					var delta: float=st.delta_l[i] if sign>0 else st.delta_r[i]
					check(absf((f.height_m-h)-delta)<=0.01,"actual intent shoulder delta <=1cm",[piece.id,st.s[i],sign,f.height_m-h,delta])
					var tie: float=st.tie_l[i] if sign>0 else st.tie_r[i]
					var daylight: Vector2=_at(d,st.s[i],sign*(half+tie+0.5))
					var natural: float=source.natural.sample_height(daylight.x,daylight.y).height_m
					var final: Dictionary=surface.sample_surface(daylight.x,daylight.y)
					check(final.is_valid and absf(final.height_m-natural)<=0.001,"actual daylight <=intent tie +0.5m",[piece.id,st.s[i],sign,tie,final.get("height_m",NAN)-natural])
					daylight_samples+=1
				if piece.info.kind=="MOVEMENT":
					for patch: Dictionary in source.route.get_data().patches:
						if patch.owner.node_id==int(piece.id.split(":")[1]):
							check(f.height_m-h<=patch.limits.fill_max_m+0.001 and h-f.height_m<=patch.limits.cut_max_m+0.001,"widened connector shoulder obeys patch cut/fill",[piece.id,i,sign,f.height_m-h])
	check(daylight_samples>0,"real intent daylight coverage")
	report["intent_daylight_samples"]=daylight_samples

func _boundary_rays(slice: Node3D,surface: RefCounted,space: PhysicsDirectSpaceState3D) -> void:
	var points: Dictionary={}
	for tile: Dictionary in slice.tiles:
		for vertex: Vector3 in tile.arrays[Mesh.ARRAY_VERTEX]:
			var x: float=vertex.x+tile.origin_x_m
			var z: float=vertex.z+tile.origin_z_m
			var tile_edge: bool=vertex.x in [0.0,512.0] or vertex.z in [0.0,512.0]
			var cell_x: int=int(floor(x/16))
			var cell_z: int=int(floor(z/16))
			var fine_edge: bool=(fmod(x,16.0)==0 and surface.is_fine_cell(cell_x-1,cell_z)!=surface.is_fine_cell(cell_x,cell_z)) or (fmod(z,16.0)==0 and surface.is_fine_cell(cell_x,cell_z-1)!=surface.is_fine_cell(cell_x,cell_z))
			if tile_edge or fine_edge: points[Vector2(x,z)]=vertex.y
	var misses:=0
	for point: Vector2 in points:
		var h: float=points[point]
		var hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x,h+20,point.y),Vector3(point.x,h-20,point.y),6))
		if hit.is_empty(): misses+=1
		else: check(absf(hit.position.y-h)<=0.005,"physical tile and fine/coarse boundary height",point)
	check(misses==0,"zero actual mesh-boundary ray misses",misses)
	report["boundary_rays"]=points.size()
	report["boundary_ray_misses"]=misses

func _collision(source: Dictionary,surface: RefCounted,space: PhysicsDirectSpaceState3D) -> void:
	var rays:=0
	var misses:=0
	var maximum_error: float=0.0
	var riding_error: float=0.0
	var ford_depths: Dictionary={}
	for reverse: bool in [false,true]:
		for p: Dictionary in source.route.get_data().pieces:
			var d: Dictionary=p.design
			for lateral: float in [-4.0,-2.55,-1.8,-1.2,0,1.2,1.8,2.55,4.0]:
				var previous: float=NAN
				for i in range(int(ceil(d.s[-1]/0.5))+1):
					var s: float=minf(i*0.5,d.s[-1])
					if reverse: s=d.s[-1]-s
					var point: Vector2=_at(d,s,lateral)
					var target: Dictionary=surface.sample_surface(point.x,point.y)
					check(target.is_valid,"ray target valid",[p.id,s,lateral])
					if not target.is_valid: continue
					var query := PhysicsRayQueryParameters3D.create(Vector3(point.x,target.height_m+20,point.y),Vector3(point.x,target.height_m-20,point.y),6)
					var hit: Dictionary=space.intersect_ray(query)
					rays+=1
					if hit.is_empty():
						misses+=1
						continue
					var error: float=absf(hit.position.y-target.height_m)
					maximum_error=maxf(maximum_error,error)
					if absf(lateral)<=1.8: riding_error=maxf(riding_error,error)
					check(error<=(0.01 if absf(lateral)<=1.8 else 0.05),"ray matches FinalSurface",[p.id,s,lateral,error])
					var expected_layer: int=2 if absf(lateral)<=2.55 else 4
					check(hit.collider.collision_layer==expected_layer,"ray preserves Road/Terrain layers",[p.id,s,lateral,hit.collider.collision_layer])
					var water: Dictionary=source.field.sample_water(point.x,point.y)
					if water.is_water and absf(lateral)<=2.55:
						var depth: float=water.water_surface_m-hit.position.y
						var range_m: Vector2=ford_depths.get(str(water.id),Vector2(INF,-INF))
						ford_depths[str(water.id)]=Vector2(minf(range_m.x,depth),maxf(range_m.y,depth))
						check(water.water_surface_m-hit.position.y>=0.02 and water.water_surface_m-hit.position.y<0.35,"actual collidable ford depth",[p.id,s,lateral,water.water_surface_m-hit.position.y])
					if absf(lateral)<=1.8:
						check(hit.normal.dot(Vector3.UP)>=cos(deg_to_rad(10.0)),"riding collision normal within 10deg")
						if is_finite(previous): check(absf(hit.position.y-previous)<=tan(deg_to_rad(5.0))*0.5+0.005,"consecutive physical hit continuity",[p.id,s,lateral])
					previous=hit.position.y
	check(misses==0,"zero actual ray misses",misses)
	report["rays"]=rays
	report["ray_misses"]=misses
	report["ray_max_error_m"]=maximum_error
	report["riding_ray_max_error_m"]=riding_error
	var ranges_m: Dictionary={}
	for id: String in ford_depths: ranges_m[id]=[ford_depths[id].x,ford_depths[id].y]
	report["ford_physical_depth_ranges_m"]=ranges_m
