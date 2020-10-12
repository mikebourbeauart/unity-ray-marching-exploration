Shader "PeerPlay/RaymarchShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "DistanceFunctions.cginc"
            
            sampler2D _MainTex;
            uniform sampler2D _CameraDepthTexture;
            uniform float4x4 _CamFrustum, _CamToWorld;
            uniform int _MaxIterations;
            uniform float _Accuracy;
            uniform float _maxDistance, _box1round, _boxSphereSmooth, _sphereIntersectSmooth;
            uniform float4 _sphere1, _sphere2, _box1;
            uniform float3 _modInterval;
            uniform float _LightIntensity;
            uniform float _ShadowIntensity;
            uniform fixed4 _mainColor;
            uniform float2 _ShadowDistance;
            uniform float _ShadowPenumbra;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 ray : TEXCOORD1;
            };

            v2f vert (appdata v)
            {
                v2f o;
                half index = v.vertex.z;
                v.vertex.z = 0;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;

                o.ray = _CamFrustum[(int)index].xyz;
                o.ray /= abs(o.ray.z);
                o.ray = mul(_CamToWorld, o.ray);

                return o;
            }
            
            float BoxSphere(float3 p) {
                float Sphere1 = sdSphere(p - _sphere1.xyz, _sphere1.w);
                float Box1 = sdRoundBox(p - _box1.xyz, _box1.www, _box1round);
                float combine1 = opSS(Sphere1, Box1, _boxSphereSmooth);
                float Sphere2 = sdSphere(p - _sphere2.xyz, _sphere2.w);
                float combine2 = opSI(Sphere2, combine1, _sphereIntersectSmooth);
                return combine2;
            }

            float distanceField(float3 p){
                float ground = sdPlane(p, float4(0,1,0,0));
                float boxSphere1 = BoxSphere(p);

                return opU(ground, boxSphere1);
            }

            float3 normal(float3 p){
                float2 e = float2(1.0,-1.0)*0.5773*0.0005;
                return normalize(	e.xyy *distanceField(p + e.xyy) + 
                                    e.yxy *distanceField(p + e.yxy) + 					  
                                    e.yyx *distanceField(p + e.yyx) + 					  
                                    e.xxx *distanceField(p + e.xxx) );
            }

            float hardShadow(float3 ro, float3 rd, float mint, float maxt){
                for (float t = mint; t < maxt;){
                    float h = distanceField(ro + rd * t);
                    if (h < 0.001){
                        return 0.0;
                    }
                    t += h;
                }
                return 1.0;
            }

            float softShadow(float3 ro, float3 rd, float mint, float maxt, float k, float3 n){
                float result = 1.0;
                for (float t = mint; t < maxt;){
                    float h = distanceField(ro + rd * t);
                    if (h < 0.001){
                        return 0.0;
                    }
                    result = min(result, k * h / t);
                    t += h;
                }
                return result * clamp(dot(n, rd), 0, 1);
            }

            uniform float _AoStepSize, _AoIntensity;
            uniform int _AoIterations;

            float AmbientOcclusion(float3 p, float3 n) {
                float step = _AoStepSize;
                float ao = 0.0;
                float dist;
                for (int i = 1; i <= _AoIterations; i++) {
                    dist = step * i;
                    ao += max(0.0, (dist - distanceField(p + n * dist)) / dist);
                }
                return (1 - ao * _AoIntensity);
            }

            float3 shading(float3 p, float3 n) {
                float3 result = (1,1,1);
                // Diffuse Color
                float3 color = _mainColor.rgb;
                // Directional Light
                fixed3 lightDir = _WorldSpaceLightPos0.xyz;
                fixed3 lightCol = _LightColor0.rgb;
                float3 light = (lightCol * dot(lightDir, n) * 0.5 + 0.5) * _LightIntensity;
                // Shadows
                float shadow = softShadow(p, lightDir, _ShadowDistance.x, _ShadowDistance.y, _ShadowPenumbra, n) * 0.5 + 0.5;
                shadow = max(0.0, pow(shadow, _ShadowIntensity));
                // Ambient Occlusion
                float ao = AmbientOcclusion(p, n);

                result *= color * light * shadow * ao;

                return result;
            }

            // ro = ray origin
            // rd = ray direction
            // t = ray travel distance
            fixed4 raymarching(float3 ro, float3 rd, float depth){
                fixed4 result = fixed4(1,1,1,1);
                const int max_iteration = _MaxIterations;
                // Distance traveled along the ray direction
                float t = 0;

                for(int i=0; i < max_iteration; i++){
                    if (t > _maxDistance || t >= depth){
                        //Environment
                        result = fixed4(rd, 0);
                        break;
                    }
                    float3 p = ro + rd * t;
                    // Check for hit in distance field
                    float d = distanceField(p);
                    // If we have hit soemthing
                    if (d < _Accuracy){
                        float3 n = normal(p);
                        float3 s = shading(p, n);

                        result = fixed4(s, 1);
                        break;
                    }
                    t += d;
                }

                return result;
            }
        
            fixed4 frag (v2f i) : SV_Target
            {
                float depth = LinearEyeDepth(tex2D(_CameraDepthTexture, i.uv).r);
                depth *= length(i.ray);
                fixed3 col = tex2D(_MainTex, i.uv);
                float3 rayDirection = normalize(i.ray.xyz);
                float3 rayOrigin = _WorldSpaceCameraPos;
                fixed4 result = raymarching(rayOrigin, rayDirection, depth);
                return fixed4(col * (1.0 - result.w) + result.xyz * result.w, 1.0);
            }
            ENDCG
        }
    }
}
