#ifndef PICKLES_SEA_WATER
#define PICKLES_SEA_WATER

float _WaterSurfaceHeight;

float3 _Extinction;
float3 _AbsorptionRatio;
half _Slope;
float _FFa;

float _InScatteringPower;

#define IOR_WATER_AIR 1.3333 // n2/n1
#define IOR_AIR_WATER 0.75018754688 // n1/n2
#define F0 0.02 //{(n1-n2)/(n1+n2)}^2
#define POW5(x) (x) * (x) * (x) * (x)

// n: index of refraction
// mu: Junge slope
float3 FournierForand3(float cosTheta, float3 n, float mu)
{
    const float nu = 1.5 - 0.5 * mu;
    const float u2 = 2 * (1 - cosTheta);
    const float3 nMinusOne = n - 1;
    const float3 delta = u2 / (3.0 * nMinusOne * nMinusOne);
    const float3 oneMinusDelta = 1 - delta;
    const float3 deltaNu = pow(delta, nu);
    const float3 oneMinusDeltaNu = 1 - deltaNu;

    float3 beta = ((nu * oneMinusDelta - oneMinusDeltaNu) +
            4.0 * (delta * oneMinusDeltaNu - nu * oneMinusDelta) / u2)
        / (4.0 * UNITY_PI * oneMinusDelta * oneMinusDelta * deltaNu);

    return beta;
}

// Freda--Piskozub 2007
// https://doi.org/10.1364/OE.15.012763
// a: absorption coefficient
// mu: Junge slope
// R:620nm, G:555nm, B:443nm
float3 FFIOR(float a, float mu)
{
    const float m = mu - 3;
    return float3(
        (2.72 * a - 0.04) * m + 1,
        (3.57 * a - 0.15) * m + 1,
        (1.34 * a - 0.36) * m + 1
    );
}

// theta = scattering angle
half WaterPhaseFunction(half cosTheta)
{
    return lerp(FournierForand3(cosTheta, FFIOR(_FFa, _Slope), _Slope), UNITY_INV_FOUR_PI, 0.5);
}

// scattering and absorption coefficients are assumed to be constants in water
inline float3 Transmittance(float depth, float3 kappa)
{
    return exp(-depth * kappa);
}

inline float DistanceToWaterSurface(float3 position, float3 dirToSurface)
{
    return (_WaterSurfaceHeight - position.y) / dirToSurface.y;
}

float3 InScatteringDirectionalLight(float3 camera, float3 position, float3 view, float3 lightRefract, float3 kappa,
                                    float3 sigma)
{
    float s = _WaterSurfaceHeight;
    camera = camera.y >= s ? camera + (s - camera.y) / view.y * view : camera;
    float depth = length(camera - position);
    const float c = 1 / (-lightRefract.y);
    float3 k = kappa * (1 + view.y * c);
    return (exp(kappa * (view.y - s + position.y) * c) - exp(- kappa * (depth + (s - position.y) * c))) * sigma / k * _InScatteringPower;
}

inline half FresnelSchlick(half3 f0, half cosTheta)
{
    return f0 + (1 - f0) * POW5(1 - cosTheta);
}

#endif
