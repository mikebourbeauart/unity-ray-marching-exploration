// Basic lambert on a raymarched sphere

Shader "Mike/Raymarch_PBR_Lit_NoRP"
{
    Properties
    {
        // _MainTex ("Texture", 2D) = "white" {}
        _Radius ("Radius", float) = 1
        _Center ("Center", vector) = (0, 0, 0, 1)
        _Color ("Color", color) = (1, 1, 1, 1)
        _MaxSteps ("Max Steps", int) = 16
        _MinDistance ("Min Distance", float) = .01
        _SpecularPower ("Specular Power", float) = .01
        _Glossiness ("Gloss", float) = .01
        _Metallic ("Metallic", float) = .01
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always
        Tags {"Queue"="Transparent"}

        
        Pass
        {
            Tags {"LightMode" = "ForwardBase"}
            Blend SrcAlpha OneMinusSrcAlpha
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #define UNITY_PASS_FORWARDBASE
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"
            #pragma multi_compile_fwdbase_fullshadows  
            #pragma target 3.0

            #define PI 3.14159265359

            float _Radius;
            float4 _Center;
            float4 _Color;
            float _MaxSteps;
            float _MinDistance;
            float _SpecularPower;
            float _Glossiness;
            float _Metallic;
            
            struct appdata {
                float4 vertex : POSITION;
                // float2 uv : TEXCOORD0;
            };

            struct v2f {
                // float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION; // Clip space
                // float4 depth : SV_DEPTH; // Clip space
                float3 wPos : TEXCOORD1; // World position
                LIGHTING_COORDS(7,8)                   //this initializes the unity lighting and shadow
                UNITY_FOG_COORDS(9)                    //this initializes the unity fog
            };

            //------------------------------------------------------------------------------
            // Distance field functions
            //------------------------------------------------------------------------------
            // Define surface shape
            float map (float3 p) {
                // Sphere at center pos with radius
                return distance(p, _Center) - _Radius;
            }

            // // Get normal at surface position
            // float3 normal (float3 p){
            //     // Epsilon
            //     const float eps = 0.01;

            //     // Gradient
            //     return normalize(
            //         float3( 
            //             map(p + float3(eps, 0, 0) ) - map(p - float3(eps, 0, 0)),
            //             map(p + float3(0, eps, 0) ) - map(p - float3(0, eps, 0)),
            //             map(p + float3(0, 0, eps) ) - map(p - float3(0, 0, eps))
            //         )
            //     );
            // }

            //------------------------------------------------------------------------------
            // Ray casting
            //------------------------------------------------------------------------------

            float shadow(in float3 origin, in float3 direction) {
                float hit = 1.0;
                float t = 0.02;
                
                for (int i = 0; i < 1000; i++) {
                    float h = map(origin + direction * t);
                    if (h < 0.001) return 0.0;
                    t += h;
                    hit = min(hit, 10.0 * h / t);
                    if (t >= 2.5) break;
                }

                return clamp(hit, 0.0, 1.0);
            }

            float2 traceRay(in float3 origin, in float3 direction) {
                float material = -1.0;

                float t = 0.02;
                
                for (int i = 0; i < 1000; i++) {
                    float2 hit = map(origin + direction * t);
                    if (hit.x < 0.002 || t > 20.0) break;
                    t += hit.x;
                    material = hit.y;
                }

                if (t > 20.0) {
                    material = -1.0;
                }

                return float2(t, material);
            }

            float3 normal (float3 p){
                // Epsilon
                const float eps = 0.01;

                // Gradient
                return normalize(
                    float3( 
                        map(p + float3(eps, 0, 0) ) - map(p - float3(eps, 0, 0)),
                        map(p + float3(0, eps, 0) ) - map(p - float3(0, eps, 0)),
                        map(p + float3(0, 0, eps) ) - map(p - float3(0, 0, eps))
                    )
                );
            }

            //------------------------------------------------------------------------------
            // BRDF
            //------------------------------------------------------------------------------

            float pow5(float x) {
                float x2 = x * x;
                return x2 * x2 * x;
            }

            float D_GGX(float linearRoughness, float NoH, const float3 h) {
                // Walter et al. 2007, "Microfacet Models for Refraction through Rough Surfaces"
                float oneMinusNoHSquared = 1.0 - NoH * NoH;
                float a = NoH * linearRoughness;
                float k = linearRoughness / (oneMinusNoHSquared + a * a);
                float d = k * k * (1.0 / PI);
                return d;
            }

            float V_SmithGGXCorrelated(float linearRoughness, float NdotV, float NdotL) {
                // Heitz 2014, "Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs"
                float a2 = linearRoughness * linearRoughness;
                float GGXV = NdotL * sqrt((NdotV - a2 * NdotV) * NdotV + a2);
                float GGXL = NdotV * sqrt((NdotL - a2 * NdotL) * NdotL + a2);
                return 0.5 / (GGXV + GGXL);
            }

            float3 F_Schlick(const float3 f0, float VoH) {
                // Schlick 1994, "An Inexpensive BRDF Model for Physically-Based Rendering"
                return f0 + (float3(1, 1, 1) - f0) * pow5(1.0 - VoH);
            }

            float F_Schlick(float f0, float f90, float VoH) {
                return f0 + (f90 - f0) * pow5(1.0 - VoH);
            }

            float Fd_Burley(float linearRoughness, float NdotV, float NdotL, float LdotH) {
                // Burley 2012, "Physically-Based Shading at Disney"
                float f90 = 0.5 + 2.0 * linearRoughness * LdotH * LdotH;
                float lightScatter = F_Schlick(1.0, f90, NdotL);
                float viewScatter  = F_Schlick(1.0, f90, NdotV);
                return lightScatter * viewScatter * (1.0 / PI);
            }

            float Fd_Lambert() {
                return 1.0 / PI;
            }

            //------------------------------------------------------------------------------
            // Indirect lighting
            //------------------------------------------------------------------------------

            float3 Irradiance_SphericalHarmonics(const float3 n) {
                // Irradiance from "Ditch River" IBL (http://www.hdrlabs.com/sibl/archive.html)
                return max(
                    float3( 0.754554516862612,  0.748542953903366,  0.790921515418539)
                    + float3(-0.083856548007422,  0.092533500963210,  0.322764661032516) * (n.y)
                    + float3( 0.308152705331738,  0.366796330467391,  0.466698181299906) * (n.z)
                    + float3(-0.188884931542396, -0.277402551592231, -0.377844212327557) * (n.x)
                    , 0.0);
            }

            float2 PrefilteredDFG_Karis(float roughness, float NoV) {
                // Karis 2014, "Physically Based Material on Mobile"
                const float4 c0 = float4(-1.0, -0.0275, -0.572,  0.022);
                const float4 c1 = float4( 1.0,  0.0425,  1.040, -0.040);

                float4 r = roughness * c0 + c1;
                float a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;

                return float2(-1.04, 1.04) * a004 + r.zw;
            }

            //------------------------------------------------------------------------------
            // Tone mapping and transfer functions
            //------------------------------------------------------------------------------

            float3 Tonemap_ACES(const float3 x) {
                // Narkowicz 2015, "ACES Filmic Tone Mapping Curve"
                const float a = 2.51;
                const float b = 0.03;
                const float c = 2.43;
                const float d = 0.59;
                const float e = 0.14;
                return (x * (a * x + b)) / (x * (c * x + d) + e);
            }

            float3 OECF_sRGBFast(const float3 _linear) {
                return pow(_linear, float3(1,1,1) / 2.2);
            }

            //------------------------------------------------------------------------------
            // Lighting
            //------------------------------------------------------------------------------
            float3 renderSurface(float3 position, float3 direction){
                float3 n = normal(position);
                fixed3 l = _WorldSpaceLightPos0.xyz; // Light direction
                fixed3 lightCol = _LightColor0.rgb; // Light color

                fixed3 v = normalize(-direction);
                fixed3 h = normalize(v + l);
                fixed3 r = normalize(reflect(direction, n));

                // Normal dot LightDir
                fixed NdotL = max(dot(n, l), 0);
                fixed NdotV = abs(dot(n, v)) + 1e-5;
                fixed NdotH = saturate(dot(n, h));
                fixed LdotH = saturate(dot(l, h));

                float3 baseColor = _Color;
                float roughness = _Glossiness;
                float metallic = _Metallic;

                float intensity = 2.0;
                float indirectIntensity = 0.64;

                float linearRoughness = roughness * roughness;
                float3 diffuseColor = (1.0 - metallic) * baseColor.rgb;
                float3 f0 = 0.04 * (1.0 - metallic) + baseColor.rgb * metallic;

                float attenuation = shadow(position, l);

                // specular BRDF
                float D = D_GGX(linearRoughness, NdotH, h);
                float V = V_SmithGGXCorrelated(linearRoughness, NdotV, NdotL);
                float3 F = F_Schlick(f0, LdotH);
                float3 Fr = (D * V) * F;

                // diffuse BRDF
                float3 Fd = diffuseColor * Fd_Burley(linearRoughness, NdotV, NdotL, LdotH);

                float3 color = (1,1,1,1);
                color = Fd + Fr;
                color *= (intensity * attenuation * NdotL) * float3(0.98, 0.92, 0.89);

                // diffuse indirect
                float3 indirectDiffuse = Irradiance_SphericalHarmonics(n) * Fd_Lambert();
                float indirectHit = traceRay(position, r);
                float3 indirectSpecular = float3(0.65, 0.85, 1.0) + r.y * 0.72;
                if (indirectHit > 0.0) {
                    indirectSpecular = float3(0.3, 0.0, 0.0);
                }

                // indirect contribution
                float2 dfg = PrefilteredDFG_Karis(roughness, NdotV);
                float3 specularColor = f0 * dfg.x + dfg.y;
                float3 ibl = diffuseColor * indirectDiffuse + indirectSpecular * specularColor;

                color += ibl * indirectIntensity;
                return color;

                fixed4 c;
                // c.rgb = _Color * lightCol * NdotL;
                c.rgb = Fd ;
                c.a = 1;
                return c;
            }

            //------------------------------------------------------------------------------
            // Ray casting
            //------------------------------------------------------------------------------
            float3 raymarch (float3 position, float3 direction) {
                for (int i = 0; i < _MaxSteps; i++) {
                    float distance = map(position);
                    if (distance < _MinDistance)
                        return renderSurface(position, direction);
                    
                    position += distance * direction;
                }
                return float3(0,0,0);
            }
            
            // Vertex function
            v2f vert (appdata v) {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.wPos = mul(unity_ObjectToWorld, v.vertex).xyz; 
                return o;
            }

            // Fragment function
            fixed4 frag (v2f i) : SV_Target {
                float3 worldPosition = i.wPos;
                float3 viewDirection = normalize(i.wPos - _WorldSpaceCameraPos);
                // Render map
                float distance;
                float3 color = raymarch(worldPosition, viewDirection);

                // Tone mapping
                //color = Tonemap_ACES(color);

                // Exponential distance fog
                // color = lerp(color, 0.8 * float3(0.7, 0.8, 1.0), 1.0 - exp2(-0.011 * distance * distance));

                // Gamma compression
                //color = OECF_sRGBFast(color);

                // return color;
                // float3 depth = raymarch(worldPosition, viewDirection);
                
                if(length(color) != 0)
                {
                    return fixed4(color, 1);
                }
                else 
                    return fixed4(1, 1, 1, 0);
            }
            ENDCG
        }
    }
}
