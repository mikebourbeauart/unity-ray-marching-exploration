// Basic lambert on a raymarched sphere

Shader "Mike/Raymarch_water"
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
        _Gloss ("Gloss", float) = .01
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

            #define PI 3.14159265359

            float _Radius;
            float4 _Center;
            float4 _Color;
            float _MaxSteps;
            float _MinDistance;
            float _SpecularPower;
            float _Gloss;
            
            struct appdata {
                float4 vertex : POSITION;
                // float2 uv : TEXCOORD0;
            };

            struct v2f {
                // float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION; // Clip space
                float3 wPos : TEXCOORD1; // World position
            };

            //------------------------------------------------------------------------------
            // Distance field functions
            //------------------------------------------------------------------------------
            // Define surface shape
            float map (float3 p) {
                // Sphere at center pos with radius
                //return distance(p, _Center) - _Radius;
                float s = distance(p, _Center) - _Radius;
                s += 0.005 * sin(7.0 * p.x + 60.0 * _Time);
                
                s += 0.02 * sin(15.0 * p.z + 40.0 * _Time);
            
                return s;
            }

            // Get normal at surface position
            float3 normal (float3 p){
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
            // Lighting
            //------------------------------------------------------------------------------
            fixed4 lambertSurface(float3 p, float3 direction){
                float3 n = normal(p);
                fixed3 l = _WorldSpaceLightPos0.xyz; // Light direction
                fixed3 lightCol = _LightColor0.rgb; // Light color
                
                // Normal dot LightDir
                fixed NdotL = max(dot(n, l), 0);

                fixed4 c;
                c.rgb = _Color * lightCol * NdotL;
                c.a = 1;
                return c;
            }

            //------------------------------------------------------------------------------
            // Ray casting
            //------------------------------------------------------------------------------
            fixed3 raymarch (float3 position, float3 direction) {
                for (int i = 0; i < _MaxSteps; i++) {
                    float distance = map(position);
                    position += distance * direction;
                    if (distance < _MinDistance)
                        break;         
                }
                return position;
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
                float dist = 0.;
                float3 position = worldPosition + dist * viewDirection;
                position = raymarch(position, viewDirection);

                fixed3 render = lambertSurface(position, viewDirection);

                float3 color = (1, 1, 0);
                
                color = float3(1,1,1);

                float ior = .7;

                float3 v = normalize(-viewDirection);
                float3 n = normal(position);
                float3 l = normalize(float3(.4,.5,.6));
                float3 h = normalize(v + l);
                float3 rl = reflect(viewDirection, n);
                float3 rr = refract(viewDirection, n, ior);
                
                float NoV = abs(dot(n, v)) + 1e-5;
                float NoL = saturate(dot(n, l));
                float NoH = saturate(dot(n, h));
                float LoH = saturate(dot(l, h));

                // Back side refract
                float3 ro2 = position + rr * .05;
                float3 position_back = raymarch(ro2, viewDirection);

                float3 n2 = normal(ro2);
                float3 rl2 = reflect(rr, -n2);
                float3 rr2 = refract(rr,-n2,ior);
                float fresnel2 = dot(-rr,n2);

                 // Iridescence refraction 
                // color.r = tex(normalize(refract(rr, -n2, ior * .98))).r;
                // color.g = tex(normalize(refract(rr, -n2, ior * 1.0))).g;
                // color.b = tex(normalize(refract(rr, -n2, ior * 1.02))).b;

                // color = mix(texture(iChannel0, rl2).xyz, color, pow(-fresnel2,.2));
                // color = mix(tex(rl)*.5, color*.7, pow(fresnel1,.15));
                color += float3(.04, .04, .04);

                color = float3(pow(color,float3(.5, .5, .5)));
                
                if (length(position) < 5.0)
                {
                    return float4(render, 1); 
                }
                else
                {   
                    return float4(1,1,1, 0);
                    
                }
            }
            ENDCG
        }
    }
}
