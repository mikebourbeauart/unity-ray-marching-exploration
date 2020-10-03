// https://www.shadertoy.com/view/XlKSDR#

Shader "Mike/RayMarch_PBRLit_NoRP"
{
    Properties
    {
        // _MainTex ("Texture", 2D) = "white" {}
        _Radius ("Radius", float) = 1
        _Center ("Center", vector) = (0, 0, 0, 1)
        _Color ("Color", color) = (1, 1, 1, 1)
        _Steps ("Steps", float) = .1
        _MinDistance ("Min Distance", float) = .01
        _SpecularPower ("Specular Power", float) = .01
        _Roughness ("Roughness", float) = .03
    }
    SubShader
    {
        // No culling or depth
        // Cull Off ZWrite Off ZTest Always
        Tags {"Queue"="Transparent"}
        
        Pass
        {
            Tags {"LightMode" = "ForwardBase"}
            Blend SrcAlpha OneMinusSrcAlpha
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            
            #define saturate(x) clamp(x, 0.0, 1.0)
            #define PI 3.14159265359
            
            float _Radius;
            float4 _Center;
            float4 _Color;
            float _Steps;
            float _MinDistance;
            float _SpecularPower;
            float _Roughness;
            float3 color;
            
            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                // float2 uv : TEXCOORD0;
            };

            struct v2f {
                // float2 uv : TEXCOORD0;
                float3 wPos : TEXCOORD1; // World position
                float4 pos : SV_POSITION; // Clip space
            };

            //------------------------------------------------------------------------------
            // Distance field functions
            //------------------------------------------------------------------------------
            float map (float3 p)
            {
                return distance(p, _Center) - _Radius;
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
                // GGX is an analytic BSDF model that takes into account micro-facet distribution of an 
                // underlying material
                float oneMinusNoHSquared = 1.0 - NoH * NoH;
                float a = NoH * linearRoughness;
                float k = linearRoughness / (oneMinusNoHSquared + a * a);
                float d = k * k * (1.0 / PI);
                return d;
            }

            float V_SmithGGXCorrelated(float linearRoughness, float NoV, float NoL) {
                // Heitz 2014, "Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs"
                float a2 = linearRoughness * linearRoughness;
                float GGXV = NoL * sqrt((NoV - a2 * NoV) * NoV + a2);
                float GGXL = NoV * sqrt((NoL - a2 * NoL) * NoL + a2);
                return 0.5 / (GGXV + GGXL);
            }

            float3 F_Schlick(const float3 f0, float VoH) {
                // Schlick 1994, "An Inexpensive BRDF Model for Physically-Based Rendering"
                return f0 + (float3(1, 1, 1) - f0) * pow5(1.0 - VoH);
            }

            float F_Schlick(float f0, float f90, float VoH) {
                // Fresnel
                return f0 + (f90 - f0) * pow5(1.0 - VoH);
            }

            float Fd_Burley(float linearRoughness, float NoV, float NoL, float LoH) {
                // Burley 2012, "Physically-Based Shading at Disney"
                float f90 = 0.5 + 2.0 * linearRoughness * LoH * LoH;
                float lightScatter = F_Schlick(1.0, f90, NoL);
                float viewScatter  = F_Schlick(1.0, f90, NoV);
                return lightScatter * viewScatter * (1.0 / PI);
            }

            float Fd_Lambert() {
                // ????
                return 1.0 / PI;
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
                // ????
                return pow(_linear, float3(1 / 2.2, 1 / 2.2, 1 / 2.2));
            }



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


            float3 normal(float3 p){
                const float eps = 0.01;

                return normalize(
                    float3( 
                        map(p + float3(eps, 0, 0) ) - map(p - float3(eps, 0, 0)),
                        map(p + float3(0, eps, 0) ) - map(p - float3(0, eps, 0)),
                        map(p + float3(0, 0, eps) ) - map(p - float3(0, 0, eps))
                    )
                );
            }

            //------------------------------------------------------------------------------
            // Rendering
            //------------------------------------------------------------------------------

            float3 renderSurface(float3 position, float3 direction) {
                 // Light
                fixed3 lightDir = _WorldSpaceLightPos0.xyz; // Light direction
                fixed3 lightCol = _LightColor0.rgb; // Light color
                
                // We've hit something in the scene
                // View direction?
                float3 v = normalize(-direction);
                // Normal
                float3 n = normal(position);
                // Light?
                // float3 l = normalize(float3(0.6, 0.7, -0.7));
                float3 l = normalize(lightDir);
                // Specular
                float3 h = normalize(v + l);
                // ??
                float3 r = normalize(reflect(direction, n));

                // ???
                float NoV = abs(dot(n, v)) + 1e-5;
                // ???
                float NoL = saturate(dot(n, l));
                // ???
                float NoH = saturate(dot(n, h));
                // ???
                float LoH = saturate(dot(l, h));

                float3 baseColor = float3(0, 0, 0);
                float roughness = 0.0;
                float metallic = 0.0;

                float intensity = 2.0;
                float indirectIntensity = 0.64;

                // Metallic objects
                baseColor = _Color;
                roughness = _Roughness;

                float linearRoughness = roughness * roughness;
                float3 diffuseColor = (1.0 - metallic) * baseColor.rgb;
                float3 f0 = 0.04 * (1.0 - metallic) + baseColor.rgb * metallic;

                float attenuation = shadow(position, l);

                // specular BRDF
                // Microfacet distribution function
                float D = D_GGX(linearRoughness, NoH, h);
                // Visibility (shadow?)
                float V = V_SmithGGXCorrelated(linearRoughness, NoV, NoL);
                // Fresnel
                float3  F = F_Schlick(f0, LoH);
                // BRDF
                float3 Fr = (D * V) * F;

                // diffuse BRDF
                float3 Fd = diffuseColor * Fd_Burley(linearRoughness, NoV, NoL, LoH);

                float3 color = Fd + Fr;

                fixed4 c;
                c.rgb = color;
                c.a = 1;
                return c;


                // color = mul((intensity * attenuation * NoL) * float3(0.98, 0.92, 0.89));

                // // diffuse indirect
                // float3 indirectDiffuse = Irradiance_SphericalHarmonics(n) * Fd_Lambert();

                // float2 indirectHit = traceRay(position, r);
                // float3 indirectSpecular = float3(0.65, 0.85, 1.0) + r.y * 0.72;
                // if (indirectHit.y > 0.0) {
                //     if (indirectHit.y < 4.0)  {
                //         float3 indirectPosition = position + indirectHit.x * r;
                //         // Checkerboard floor
                //         float f = fmod(floor(6.0 * indirectPosition.z) + floor(6.0 * indirectPosition.x), 2.0);
                //         indirectSpecular = 0.4 + f * float3(0.6, 0.6, 0.6);
                //     } else if (indirectHit.y < 16.0) {
                //         // Metallic objects
                //         indirectSpecular = float3(0.3, 0.0, 0.0);
                //     }
                // }

                // // indirect contribution
                // float2 dfg = PrefilteredDFG_Karis(roughness, NoV);
                // float3 specularColor = f0 * dfg.x + dfg.y;
                // float3 ibl = diffuseColor * indirectDiffuse + indirectSpecular * specularColor;

                // color += ibl * indirectIntensity;
            
            }

            
            
            

            // // Fragment function
            // fixed4 frag (v2f i) : SV_Target {
            //     // Normalized coordinates
            //     // float2 p = -1.0 + 2.0 * fragCoord.xy / iResolution.xy;
            //     // Aspect ratio
            //     // p.x = mul(iResolution.x / iResolution.y);

            //     float3 worldPosition = i.wPos;

            //     // Camera position and "look at"
            //     // float3 origin = float3(0.0, 0.8, 0.0);
            //     // float3 target = float3(0, 0, 0);

            //     // origin.x += 1.7 * cos(_Time * 0.2);
            //     // origin.z += 1.7 * sin(_Time * 0.2);

            //     // float3x3 toWorld = setCamera(origin, target, 0.0);
            //     // float3 direction = toWorld * normalize(float3(p.xy, 2.0));
            //     float3 viewDirection = normalize(i.wPos - _WorldSpaceCameraPos);

            //     // Render scene
            //     float distance;

            //     float3 color = _Center, viewDirection, distance);

            //     // Tone mapping
            //     // color = Tonemap_ACES(color);

            //     // Exponential distance fog
            //     // color = lerp(color, 0.8 * float3(0.7, 0.8, 1.0), 1.0 - exp2(-0.011 * distance * distance));

            //     // Gamma compression
            //     // color = OECF_sRGBFast(color);

            //     return fixed4(color, 1.0);
            // }



            //------------------------------------------------------------------------------    
            // Ray casting
            //------------------------------------------------------------------------------            
            float3 traceRay(float3 position, float3 direction) {
                // float material = -1.0;
                // float t = 0.02;
                
                for (int i = 0; i < _Steps; i++) {
                    float distance = map(position);
                    if (distance < _MinDistance){
                        return renderSurface(position, direction);
                    }
                    position += distance * direction;
                }

                return float3(0,0,0);
            }

            // Vertex function
            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.wPos = mul(unity_ObjectToWorld, v.vertex).xyz; 
                return o;
            }

            // Fragment function
            fixed4 frag (v2f i) : SV_Target {
                float3 worldPosition = i.wPos;
                float3 viewDirection = normalize(i.wPos - _WorldSpaceCameraPos);
                float3 depth = traceRay(worldPosition, viewDirection);

                // Normal
                half3 worldNormal = depth - float3(0,0,0);
                half normal = max(0, dot(worldNormal, _WorldSpaceLightPos0.xyz));

                if(length(depth) != 0)
                {
                    depth *= normal * _LightColor0;
                    return fixed4(depth, 1);
                }
                else 
                    return fixed4(1, 1, 1, 0);
            }
            ENDCG
        }
    }
}
