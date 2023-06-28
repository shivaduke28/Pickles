Shader "Pickles/UnderWaterSurface"
{
    Properties
    {
        [HDR]_Skybox("Skybox", Cube) = ""{}
        _SkyboxTint("Skybox Tint", Color) = (0.5, 0.5 , 0.5)
        _WaterColor ("Water Color", Color) = (0.2, 0.8, 1, 1)
//        _Extinction("Extinction coef (1/m)", Vector) = (1.2, 0.31, 0.46)
//        _AbsorptionRatio("Absorption ratio ([0, 1]^3)", Vector) = (0, 0, 0)
//        _Mie("Mie g", Range(-1, 1)) = 0.5
//        _FFa("FF a", Range(0 , 1)) = 0.5
//        _Slope("FF slope", Range(3, 5)) = 3
        _Roughness("Roughness", Range(0, 1)) = 0.1
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque" "Queue"="Transparent"
        }
        Pass
        {
            Tags
            {
                "LightMode" = "ForwardBase"
            }
            Blend One Zero

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include <UnityLightingCommon.cginc>
            #include <UnityStandardBRDF.cginc>
            #include "UnityCG.cginc"

            #define IOR_WATER_AIR 1.3333 // n2/n1
            #define IOR_AIR_WATER 0.75018754688 // n1/n2
            #define F0 0.02 //{(n1-n2)/(n1+n2)}^2
            #define POW5(x) (x) * (x) * (x) * (x)

            struct appdata
            {
                float4 vertex : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float3 worldPos : TEXCOORD1;
                float4 screenPos : TEXCOORD2;
                float4 vertex : SV_POSITION;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            float3 _WaterColor;
            float3 _Extinction;
            float3 _AbsorptionRatio;
            float _Mie;
            float _Slope;
            float _FFa;

            half _Roughness;
            UNITY_DECLARE_TEXCUBE(_Skybox);
            half3 _SkyboxTint;

            v2f vert(appdata v)
            {
                v2f o;

                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.screenPos = ComputeScreenPos(o.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                UNITY_TRANSFER_FOG(o, o.vertex);
                return o;
            }


            float2 hash2(float2 st)
            {
                st = float2(dot(st, float2(127.1, 311.7)),
                            dot(st, float2(269.5, 183.3)));
                return -1.0 + 2.0 * frac(sin(st) * 43758.5453123); // -1 ~ 1
            }

            float2x2 rotate2d(float t)
            {
                float c = cos(t), s = sin(t);
                return float2x2(c, -s, s, c);
            }

            float PerlinNoise(float2 st)
            {
                float2 p = floor(st);
                float2 f = frac(st);
                float2 u = f * f * (3.0 - 2.0 * f);

                float2 v00 = hash2(p + float2(0, 0));
                float2 v10 = hash2(p + float2(1, 0));
                float2 v01 = hash2(p + float2(0, 1));
                float2 v11 = hash2(p + float2(1, 1));

                return lerp(lerp(dot(v00, f - float2(0, 0)), dot(v10, f - float2(1, 0)), u.x),
                            lerp(dot(v01, f - float2(0, 1)), dot(v11, f - float2(1, 1)), u.x),
                            u.y) + 0.5;
            }

            static int OCTAVES = 6;

            float FBM(float2 st)
            {
                float f = 0;
                float amplitude = 0.5;
                float2 shift = float2(10.0, 10.0);
                float2x2 rot = rotate2d(0.5);
                for (int i = 0; i < OCTAVES; i++)
                {
                    f += amplitude * PerlinNoise(st);
                    st = mul(rot, st) * 2.0 + shift + _Time.y * float(i + 1) * 0.2;
                    amplitude *= 0.5;
                }
                return f;
            }

            float2 SurfaceGrad(float2 st)
            {
                // todo: compute grad directory (may be possible)
                float2 ep = float2(1e-2, 0);
                return float2(
                    FBM(st + ep) - FBM(st - ep),
                    FBM(st + ep.yx) - FBM(st - ep.yx)
                );
            }

            // Schlick approximation of the Henyey--Greenstein phase function
            half HGApprox(half cosTheta, half g)
            {
                half k = 1.55 * g - 0.55 * g * g * g;
                half a = 1 + k * cosTheta;
                return (1 - k * k) / (UNITY_FOUR_PI * a * a);
            }

            // n: index of refraction
            // mu: Junge slope
            float3 FournierForand3(float cosTheta, float3 n, float mu)
            {
                float nu = 1.5 - 0.5 * mu;
                float u2 = 2 * (1 - cosTheta);
                float3 nMinusOne = n - 1;
                float3 delta = u2 / (3.0 * nMinusOne * nMinusOne);
                float3 oneMinusDelta = 1 - delta;
                float3 deltaNu = pow(delta, nu);
                float3 oneMinusDeltaNu = 1 - deltaNu;

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
                float m = mu - 3;
                return float3(
                    (2.72 * a - 0.04) * m + 1,
                    (3.57 * a - 0.15) * m + 1,
                    (1.34 * a - 0.36) * m + 1
                );
            }

            inline half FresnelSchlick(half3 f0, half cosTheta)
            {
                return f0 + (1 - f0) * POW5(1 - cosTheta);
            }

            // write your surface normal function here.
            half3 ComputeNormal(float3 position)
            {
                float2 grad = SurfaceGrad(position.xz * 0.3 + float2(0, _Time.y * 0.2)) * 10;
                return normalize(float3(grad.x, 1, grad.y));
            }

            // theta = scattering angle
            half WaterPhaseFunction(half cosTheta)
            {
                return lerp(FournierForand3(cosTheta, FFIOR(_FFa, _Slope), _Slope), UNITY_INV_FOUR_PI, 0);
            }

            // scattering and absorption coefficients are assumed to be constants in water
            inline float Transmittance(float depth, float kappa)
            {
                return exp(-depth * kappa);
            }

            float3 InScatteringDirectionalLight(float3 view, float3 lightRefract, float depth, float3 kappa,
                                                float3 sigma)
            {
                float a = abs(view.y) / max(0.001, abs(lightRefract.y));
                float3 b = (a - 1) * kappa;
                return sigma * exp(- kappa * a * depth) * (exp(b * depth) - 1) / b;
            }

            half4 frag(v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float3 position = i.worldPos;
                half3 view = _WorldSpaceCameraPos - position;
                half depth = length(view);
                view /= depth;

                half3 normal = ComputeNormal(position);

                half3 viewRefract = refract(-view, normal * -1, IOR_WATER_AIR);
                half3 NdotVR = max(0, dot(normal, viewRefract));
                half vrFresnel = FresnelSchlick(F0, NdotVR);

                // refract color
                // TODO: choose LOD
                half3 skyColor = UNITY_SAMPLE_TEXCUBE_LOD(_Skybox, viewRefract, 0) * _SkyboxTint;
                half3 skyRefractColor = skyColor * NdotVR
                    * (1 - vrFresnel) * IOR_WATER_AIR * IOR_WATER_AIR;

                // sun light
                half3 lightColor = _LightColor0;
                half3 light = normalize(_WorldSpaceLightPos0.xyz);
                half NdotL = max(0, dot(normal, light));
                half lightFresnel = FresnelSchlick(F0, NdotL);

                half3 lightRefract = refract(-light, normal, IOR_AIR_WATER);
                skyRefractColor += GGXTerm(dot(view, lightRefract), _Roughness)
                    * lightColor
                    * (1 - lightFresnel) * IOR_WATER_AIR * IOR_WATER_AIR;

                // reflection from sea.
                half3 reflectColor = _WaterColor * vrFresnel;

                half3 col = skyRefractColor + reflectColor;

                // transmittance
                float3 kappa = _Extinction;
                float3 absorptionRatio = saturate(_AbsorptionRatio);
                float3 alpha = kappa * absorptionRatio;
                float3 sigma = kappa * (1 - absorptionRatio);
                col *= Transmittance(depth, kappa);

                // directional light scattering
                half3 scattering =
                    InScatteringDirectionalLight(view, lightRefract, depth, kappa, sigma)
                    * WaterPhaseFunction(dot(view, lightRefract))
                    * lightColor * (1 - lightFresnel) * IOR_WATER_AIR * IOR_WATER_AIR
                    * UNITY_PI;
                col += scattering;

                // skylight scattering (fake)
                half3 direction = float3(0, 1, 0);
                half3 directionRef = refract(direction, float3(0, -1, 0), IOR_WATER_AIR);
                half NdotDR = directionRef.y;
                half drFresnel = FresnelSchlick(F0, NdotDR);

                half3 skyScattering =
                    InScatteringDirectionalLight(view, direction, depth, kappa, sigma)
                    * UNITY_INV_FOUR_PI
                    * (1 - drFresnel)
                    * float3(1, 1, 1)
                    * IOR_WATER_AIR * IOR_WATER_AIR
                    * UNITY_PI;

                col += skyScattering;

                return half4(col, 1);
            }
            ENDCG
        }
    }
}