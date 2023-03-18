Shader "Pickles/UnderWaterObject"
{
    Properties
    {
        _BaseColor("Color", Color) = (1 ,1, 1)
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
        LOD 100

        Pass
        {
            Tags
            {
                "LightMode" = "ForwardBase"
            }

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "SeaWater.hlsl"
            #include <UnityLightingCommon.cginc>

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldPos: TEXCOORD1;
                float3 normal : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            half3 _BaseColor;

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            float3 frag(v2f i) : SV_Target
            {
                float3 col = tex2D(_MainTex, i.uv) * _BaseColor;

                float3 normal = normalize(i.normal);

                // sun light
                float3 lightColor = _LightColor0;
                float3 light = normalize(_WorldSpaceLightPos0.xyz);
                half NdotL = max(0, dot(float3(0, 1, 0), light));
                half lightFresnel = FresnelSchlick(F0, NdotL);


                float3 camera = _WorldSpaceCameraPos;
                float3 position = i.worldPos;
                float3 view = _WorldSpaceCameraPos - position;
                float depth = length(view);
                view /= depth;

                float3 kappa = max(0, _Extinction);
                float3 absorptionRatio = saturate(_AbsorptionRatio);
                float3 alpha = kappa * absorptionRatio;
                float3 sigma = kappa * (1 - absorptionRatio);

                col *= max(0., dot(light, normal)) * lightColor
                    * Transmittance(DistanceToWaterSurface(position, light), kappa);

                float waterDepth = camera.y >= _WaterSurfaceHeight ? DistanceToWaterSurface(position, view) : depth;
                col *= Transmittance(waterDepth, kappa);

                float3 lightRefract = refract(-light, float3(0, 1, 0), IOR_AIR_WATER);

                // directional light scattering
                float3 scattering =
                    InScatteringDirectionalLight(camera, position, view, lightRefract, kappa, sigma)
                    * WaterPhaseFunction(dot(view, lightRefract))
                    * lightColor * (1 - lightFresnel) * IOR_WATER_AIR * IOR_WATER_AIR
                    * UNITY_PI;
                col += scattering;

                // skylight scattering (fake)
                float3 direction = float3(0, 1, 0);
                float3 directionRef = refract(direction, float3(0, -1, 0), IOR_WATER_AIR);
                half NdotDR = directionRef.y;
                half drFresnel = FresnelSchlick(F0, NdotDR);

                half3 skyScattering =
                    InScatteringDirectionalLight(camera, position, view, -direction, kappa, sigma)
                    * UNITY_INV_FOUR_PI
                    // * (1 - drFresnel)
                    * float3(1, 1, 1)
                    * IOR_WATER_AIR * IOR_WATER_AIR
                    * UNITY_PI;
                col += skyScattering;

                col = position.y >= 0 ? max(0.1, NdotL) * _BaseColor : col;

                return col;
            }
            ENDCG
        }
    }
}