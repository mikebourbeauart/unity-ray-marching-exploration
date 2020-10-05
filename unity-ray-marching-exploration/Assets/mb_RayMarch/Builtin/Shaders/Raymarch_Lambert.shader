// Basic lambert on a raymarched sphere

Shader "Mike/Raymarch_lambert"
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
                return distance(p, _Center) - _Radius;
            }

            // Get normal at surface position
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
            // Lighting
            //------------------------------------------------------------------------------
            fixed4 renderSurface(float3 p, float3 direction){
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
            fixed4 raymarch (float3 position, float3 direction) {
                for (int i = 0; i < _MaxSteps; i++) {
                    float distance = map(position);
                    if (distance < _MinDistance)
                        return renderSurface(position, direction);
                    
                    position += distance * direction;
                }
                return fixed4(1,1,1,0);
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
                return raymarch(worldPosition, viewDirection);
            }
            ENDCG
        }
    }
}
