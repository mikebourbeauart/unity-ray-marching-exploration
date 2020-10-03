
Shader "Custom/03SurfaceShading"
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
            float _Steps;
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

            

            fixed4 simpleLambert (fixed3 normal, fixed3 viewDirection) {
                // Diff
                fixed3 lightDir = _WorldSpaceLightPos0.xyz; // Light direction
                fixed3 lightCol = _LightColor0.rgb; // Light color
                // Specular
                fixed3 h = (lightDir - viewDirection) / 2.;
                fixed s = pow( dot(normal, h), _SpecularPower) * _Gloss;

                fixed NdotL = max(dot(normal, lightDir),0);
                fixed4 c;
                c.rgb = _Color * lightCol * NdotL + s;
                c.a = 1;
                return c;
            }

            float map (float3 p)
            {
                return distance(p, _Center) - _Radius;
            }

            float3 normal (float3 p)
            {
                const float eps = 0.01;
                
                return normalize(
                    float3( 
                        map(p + float3(eps, 0, 0) ) - map(p - float3(eps, 0, 0)),
                        map(p + float3(0, eps, 0) ) - map(p - float3(0, eps, 0)),
                        map(p + float3(0, 0, eps) ) - map(p - float3(0, 0, eps))
                    )
                );
            }

            fixed4 renderSurface(float3 p, float3 direction)
            {
            float3 n = normal(p);
            return simpleLambert(n, direction);
            }

            fixed4 raymarch (float3 position, float3 direction) {
                for (int i = 0; i < _Steps; i++) {
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
