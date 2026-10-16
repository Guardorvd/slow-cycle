using System;
using Godot;
using Godot.Collections;

namespace SlowCycle;

/// <summary>
/// C# port of the MacroTerrainEvaluator height kernel (_sample and helpers),
/// used through MacroTerrainEvaluator.sample_prepared when the .NET build is
/// available. Bit-identical to the GDScript kernel: every double operation in
/// the same order, Godot's min/max/clamp/lerp definitions, and the float32
/// rounding Godot's Vector2 / Vector3 return values impose (F()). The context
/// arrays are copied once from the prepared GDScript Context (Setup); after
/// that the kernel is read-only and may be shared by threads.
/// </summary>
public partial class MacroTerrainKernel : RefCounted
{
    private const double SmoothMaxM = 35.0;
    private const double CellM = 256.0;
    private const int Cells = 18;
    private const int Stride = 16;
    private const double DomainSizeM = 4096.0;
    private const double ValleyPointSpacingM = 512.0;
    private const int GroupMain = 0;
    private const int GroupFar = 1;

    private int _symmetry;
    private long _structureSeed;
    private long _noiseSeed;
    private double[] _axis = System.Array.Empty<double>();
    private double[] _half = System.Array.Empty<double>();
    private double[] _nearWall = System.Array.Empty<double>();
    private double[] _farWall = System.Array.Empty<double>();
    private double _floorCm;
    private double _dropCm;
    private double _basinU;
    private double _basinExtra;
    private double _basinHalfLength;
    private double[] _wallW = System.Array.Empty<double>();
    private double[] _wallH = System.Array.Empty<double>();
    private double[] _upland = System.Array.Empty<double>();
    private double[][] _benches = System.Array.Empty<double[]>();
    private double[][] _basins = System.Array.Empty<double[]>();
    private double _rounding;
    private double _ribStrength;
    private double _ribWavelength;
    private double _warpAmplitude;
    private double _warpWavelength;
    private double[] _segments = System.Array.Empty<double>();
    private int[][] _cells = System.Array.Empty<int[]>();
    private double _noiseAmplitude;
    private double[] _noiseWavelengths = System.Array.Empty<double>();
    private double[] _noiseWeights = System.Array.Empty<double>();
    private double _ridged;
    private double[] _attenuation = System.Array.Empty<double>();
    private double _maxSummit;

    /// <summary>Copies a prepared Context (MacroTerrainEvaluator.kernel_data).</summary>
    public void Setup(Dictionary d)
    {
        _symmetry = d["symmetry"].AsInt32();
        _structureSeed = d["structure_seed"].AsInt64();
        _noiseSeed = d["noise_seed"].AsInt64();
        _axis = d["axis"].AsFloat64Array();
        _half = d["half"].AsFloat64Array();
        _nearWall = d["near_wall"].AsFloat64Array();
        _farWall = d["far_wall"].AsFloat64Array();
        _floorCm = d["floor_cm"].AsDouble();
        _dropCm = d["drop_cm"].AsDouble();
        _basinU = d["basin_u"].AsDouble();
        _basinExtra = d["basin_extra"].AsDouble();
        _basinHalfLength = d["basin_half_length"].AsDouble();
        _wallW = d["wall_w"].AsFloat64Array();
        _wallH = d["wall_h"].AsFloat64Array();
        _upland = d["upland"].AsFloat64Array();
        _benches = Rows(d["benches"].AsGodotArray());
        _basins = Rows(d["basins"].AsGodotArray());
        _rounding = d["rounding"].AsDouble();
        _ribStrength = d["rib_strength"].AsDouble();
        _ribWavelength = d["rib_wavelength"].AsDouble();
        _warpAmplitude = d["warp_amplitude"].AsDouble();
        _warpWavelength = d["warp_wavelength"].AsDouble();
        _segments = d["segments"].AsFloat64Array();
        var cells = d["cells"].AsGodotArray();
        _cells = new int[cells.Count][];
        for (int i = 0; i < cells.Count; i++)
            _cells[i] = cells[i].AsInt32Array();
        _noiseAmplitude = d["noise_amplitude"].AsDouble();
        _noiseWavelengths = d["noise_wavelengths"].AsFloat64Array();
        _noiseWeights = d["noise_weights"].AsFloat64Array();
        _ridged = d["ridged"].AsDouble();
        _attenuation = d["attenuation"].AsFloat64Array();
        _maxSummit = d["max_summit"].AsDouble();
    }

    private static double[][] Rows(Godot.Collections.Array rows)
    {
        var o = new double[rows.Count][];
        for (int i = 0; i < rows.Count; i++)
            o[i] = rows[i].AsFloat64Array();
        return o;
    }

    /// <summary>Elevation at region-local (x, z); MacroTerrainEvaluator._sample.</summary>
    public double Sample(double x, double z, bool includeNoise)
    {
        LocalToFrame(_symmetry, x, z, out double u, out double v);
        Base(u, v, out double baseRise, out double excess, out bool near);
        double wallW = WallW(u, near);
        double benchShift = 0.0;
        foreach (var bench in _benches)
        {
            if ((bench[0] > 0.0) == near)
                benchShift = Max(benchShift, bench[4] * Smooth((u - bench[1]) / 250.0) * Smooth((bench[2] - u) / 250.0));
        }
        double mask = Smooth((excess - benchShift - 0.25 * wallW) / (0.85 * wallW));
        double wu = u;
        double wv = v;
        if (_warpAmplitude > 0.0)
        {
            wu += _warpAmplitude * (0.7 * ValueNoise(_structureSeed, u, v, _warpWavelength, 1) + 0.3 * ValueNoise(_structureSeed, u, v, _warpWavelength * 0.5, 2));
            wv += _warpAmplitude * (0.7 * ValueNoise(_structureSeed, u, v, _warpWavelength, 3) + 0.3 * ValueNoise(_structureSeed, u, v, _warpWavelength * 0.5, 4));
        }
        double mountain = 0.0;
        if (mask > 0.0)
        {
            double rib = 1.0 - 2.0 * Math.Abs(ValueNoise(_structureSeed, wu, wv, _ribWavelength, 5));
            mountain = mask * Ridges(near ? GroupMain : GroupFar, wu, wv, rib);
        }
        double elevation = Floor(u) + SmoothMax(baseRise, mountain);
        double basinWeight = 0.0;
        foreach (var basin in _basins)
        {
            double du = wu - basin[0];
            double dv = wv - basin[1];
            double along = (du * basin[5] + dv * basin[6]) / basin[7];
            double across = -du * basin[6] + dv * basin[5];
            double r = Math.Sqrt(along * along + across * across) / basin[2];
            if (r < 1.0)
            {
                double weight = 1.0 - Smooth((r - 0.45) / 0.55);
                elevation = Lerp(elevation, basin[4] + 0.3 * basin[3] * r * r, weight);
                basinWeight = Max(basinWeight, weight);
            }
        }
        if (!includeNoise)
            return elevation;
        double fbm = 0.0;
        for (int octave = 0; octave < _noiseWeights.Length; octave++)
            fbm += _noiseWeights[octave] * ValueNoise(_noiseSeed, u, v, _noiseWavelengths[octave], 10 + octave);
        double ridged = 1.0 - 2.0 * Math.Abs(ValueNoise(_noiseSeed, u, v, 420.0, 20));
        double share = _ridged * Clamp(mountain / _maxSummit, 0.0, 1.0);
        double mixed = (1.0 - share) * fbm + share * ridged;
        double attenuation = Lerp(_attenuation[0], 1.0, Smooth(excess / (0.6 * wallW)));
        double benchMask = 0.0;
        foreach (var bench in _benches)
        {
            if ((bench[0] > 0.0) == near)
            {
                double e1 = 0.4 * wallW;
                double acrossBench = Smooth((excess - e1 + 40.0) / 80.0) * Smooth((e1 + bench[4] + 40.0 - excess) / 80.0);
                benchMask = Max(benchMask, acrossBench * Smooth((u - bench[1]) / 250.0) * Smooth((bench[2] - u) / 250.0));
            }
        }
        attenuation = Min(attenuation, Lerp(1.0, _attenuation[1], benchMask));
        attenuation = Min(attenuation, Lerp(1.0, _attenuation[2], basinWeight));
        return elevation + _noiseAmplitude * attenuation * mixed;
    }

    /// <summary>Elevations of many points (region-local x, z pairs).</summary>
    public double[] SampleMany(double[] xz, bool includeNoise)
    {
        var o = new double[xz.Length / 2];
        for (int i = 0; i < o.Length; i++)
            o[i] = Sample(xz[2 * i], xz[2 * i + 1], includeNoise);
        return o;
    }

    // Godot's Vector2 / Vector3 components are float32 (real_t).
    private static double F(double value) => (float)value;

    // Godot core: MAX / MIN / CLAMP ternaries, Math::lerp.
    private static double Max(double a, double b) => a > b ? a : b;
    private static double Min(double a, double b) => a < b ? a : b;
    private static double Clamp(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
    private static double Lerp(double from, double to, double weight) => from + (to - from) * weight;

    private static double Smooth(double t)
    {
        t = Clamp(t, 0.0, 1.0);
        return t * t * (3.0 - 2.0 * t);
    }

    private static double SoftRamp(double x, double b)
    {
        if (x <= -b)
            return 0.0;
        if (x >= b)
            return x;
        return (x + b) * (x + b) / (4.0 * b);
    }

    private static double SmoothMax(double a, double b)
    {
        double k = Min(SmoothMaxM, Min(a, b));
        if (k <= 0.0)
            return Max(a, b);
        double h = Clamp(0.5 + 0.5 * (a - b) / k, 0.0, 1.0);
        return Lerp(b, a, h) + k * h * (1.0 - h);
    }

    private static double Hash(long seed, long ix, long iz, long salt)
    {
        long h = (seed & 0x7fffffff) ^ (((seed >> 31) & 0x7fffffff) * 0x45d9f3b & 0x7fffffff) ^ (((seed >> 62) & 1) * 0x5bd1e995);
        h ^= ((ix & 0x7fffffff) * 0x27d4eb2d) & 0x7fffffff;
        h = ((h ^ (h >> 15)) * 0x2c1b3c6d) & 0x7fffffff;
        h ^= ((iz & 0x7fffffff) * 0x165667b1) & 0x7fffffff;
        h = ((h ^ (h >> 13)) * 0x297a2d39) & 0x7fffffff;
        h ^= (salt * 0x3c6ef372) & 0x7fffffff;
        h = ((h ^ (h >> 16)) * 0x45d9f3b) & 0x7fffffff;
        h ^= h >> 15;
        return h / 2147483647.0 * 2.0 - 1.0;
    }

    private static double ValueNoise(long seed, double x, double z, double wavelength, long salt)
    {
        double sx = x / wavelength;
        double sz = z / wavelength;
        long ix = (long)Math.Floor(sx);
        long iz = (long)Math.Floor(sz);
        double tx = sx - ix;
        double tz = sz - iz;
        tx = tx * tx * tx * (tx * (tx * 6.0 - 15.0) + 10.0);
        tz = tz * tz * tz * (tz * (tz * 6.0 - 15.0) + 10.0);
        double a = Lerp(Hash(seed, ix, iz, salt), Hash(seed, ix + 1, iz, salt), tx);
        double b = Lerp(Hash(seed, ix, iz + 1, salt), Hash(seed, ix + 1, iz + 1, salt), tx);
        return Lerp(a, b, tz);
    }

    private static void LocalToFrame(int symmetry, double x, double z, out double u, out double v)
    {
        switch (symmetry % 4)
        {
            case 0: u = F(x); v = F(z); break;
            case 1: u = F(z); v = F(DomainSizeM - x); break;
            case 2: u = F(DomainSizeM - x); v = F(DomainSizeM - z); break;
            default: u = F(DomainSizeM - z); v = F(x); break;
        }
        if (symmetry >= 4)
            v = F(DomainSizeM - v);
    }

    // MacroTerrainPlan.spline: (value, slope per metre), both float32.
    private static void Spline(double[] values, double u, out double value, out double slope)
    {
        int last = values.Length - 1;
        double s = Clamp(u / ValleyPointSpacingM, 0.0, last);
        long fi = (long)Math.Floor(s);
        int i = (int)(fi < last - 1 ? fi : last - 1);
        double t = s - i;
        double p0 = values[Math.Max(i - 1, 0)];
        double p1 = values[i];
        double p2 = values[i + 1];
        double p3 = values[Math.Min(i + 2, last)];
        double m1 = (p2 - p0) / (i > 0 ? 2.0 : 1.0);
        double m2 = (p3 - p1) / (i + 1 < last ? 2.0 : 1.0);
        double t2 = t * t;
        double t3 = t2 * t;
        double val = (2 * t3 - 3 * t2 + 1) * p1 + (t3 - 2 * t2 + t) * m1 + (-2 * t3 + 3 * t2) * p2 + (t3 - t2) * m2;
        double sl = (6 * t2 - 6 * t) * p1 + (3 * t2 - 4 * t + 1) * m1 + (-6 * t2 + 6 * t) * p2 + (3 * t2 - 2 * t) * m2;
        value = F(val);
        slope = F(sl / ValleyPointSpacingM);
    }

    private static double SplineValue(double[] values, double u)
    {
        Spline(values, u, out double value, out _);
        return value;
    }

    private void Wall(double u, bool near, out double width, out double height)
    {
        int k = near ? 1 : 0;
        double scale = SplineValue(near ? _nearWall : _farWall, u);
        width = F(_wallW[k] * (1.0 + scale) * 0.5);
        height = F(_wallH[k] * scale);
    }

    private double WallW(double u, bool near)
    {
        Wall(u, near, out double width, out _);
        return width;
    }

    private double Floor(double u) => (_floorCm + _dropCm * (1.0 - Clamp(u / 4096.0, 0.0, 1.0))) / 100.0;

    private void Base(double u, double v, out double rise, out double excessOut, out bool near)
    {
        Spline(_axis, u, out double axisX, out double axisY);
        double half = SplineValue(_half, u);
        double x = (u - _basinU) / _basinHalfLength;
        double widening = _basinExtra * Math.Pow(Max(0.0, 1.0 - x * x), 3);
        double d = (v - axisX) / Math.Sqrt(1.0 + axisY * axisY);
        near = d >= 0.0;
        double excess = near ? (d - half) : (-d - half - widening);
        Wall(u, near, out double wallW, out double wallH);
        double upland = _upland[near ? 1 : 0];
        double r = wallH * Smooth(excess / wallW) + upland * SoftRamp(excess - wallW, 120.0);
        foreach (var bench in _benches)
        {
            if ((bench[0] > 0.0) != near)
                continue;
            double weight = Smooth((u - bench[1]) / 250.0) * Smooth((bench[2] - u) / 250.0);
            if (weight <= 0.0)
                continue;
            double e1 = 0.4 * wallW;
            double e2 = e1 + bench[4];
            double benched = bench[3] * wallH * Smooth(excess / e1) + 0.02 * Clamp(excess - e1, 0.0, bench[4])
                + (1.0 - bench[3]) * wallH * Smooth((excess - e2) / (wallW - e1)) + upland * SoftRamp(excess - wallW - bench[4], 120.0);
            r = Lerp(r, benched, weight);
        }
        rise = F(r);
        excessOut = F(excess);
    }

    private double Ridges(int group, double u, double v, double rib)
    {
        int[] list = null;
        bool brute = _cells.Length == 0;
        if (!brute)
        {
            long i = (long)Math.Floor(u / CellM) + 1;
            long j = (long)Math.Floor(v / CellM) + 1;
            i = i < 0 ? 0 : (i > Cells - 1 ? Cells - 1 : i);
            j = j < 0 ? 0 : (j > Cells - 1 ? Cells - 1 : j);
            list = _cells[j * Cells + i];
        }
        int count = brute ? _segments.Length / Stride : list.Length;
        double result = -1.0;
        double[] seg = _segments;
        for (int n = 0; n < count; n++)
        {
            int s = brute ? n * Stride : list[n];
            if ((long)seg[s + 11] != group || u < seg[s + 12] || v < seg[s + 13] || u > seg[s + 14] || v > seg[s + 15])
                continue;
            double au = seg[s];
            double av = seg[s + 1];
            double du = seg[s + 2] - au;
            double dv = seg[s + 3] - av;
            double lengthSquared = du * du + dv * dv;
            double t = lengthSquared <= 0.0 ? 0.0 : Clamp(((u - au) * du + (v - av) * dv) / lengthSquared, 0.0, 1.0);
            double pu = u - (au + t * du);
            double pv = v - (av + t * dv);
            double distance = Math.Sqrt(pu * pu + pv * pv);
            double near = Lerp(seg[s + 6], seg[s + 7], t);
            double far = Lerp(seg[s + 8], seg[s + 9], t);
            if (distance >= Max(near, far))
                continue;
            double towardValley = (group == GroupMain ? -pv : pv) / Max(distance, 1e-6);
            double width = Lerp(far, near, Smooth(0.5 + towardValley / 0.6));
            if (distance >= width)
                continue;
            double soft = (Math.Sqrt(distance * distance + _rounding * _rounding) - _rounding) / (Math.Sqrt(width * width + _rounding * _rounding) - _rounding);
            double value = Lerp(seg[s + 4], seg[s + 5], t) * Math.Pow(1.0 - soft, seg[s + 10]) * (1.0 + _ribStrength * rib * 4.0 * soft * (1.0 - soft));
            result = result < 0.0 ? value : SmoothMax(result, value);
        }
        return Max(result, 0.0);
    }
}
