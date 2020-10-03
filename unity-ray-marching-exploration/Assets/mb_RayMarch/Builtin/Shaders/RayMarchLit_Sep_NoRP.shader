Shader "Mike/RayMarchLit_Sep_NoRP"
{
    Properties
    {
        // _MainTex ("Texture", 2D) = "white" {}
        _Radius ("Radius", Float) = 1
        _Center ("Center", Vector) = (1,0,0,1)
        _Color ("Color", Color) = (1, 1, 1, 1)
        _Step ("Step", Float) = .1
        _MaxStep ("Max Step", Float) = .01
        _SpecularPower ("Specular Power", Float) = 0
        _Gloss ("Gloss", Float) = 0
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
            float _Step;
            float _MaxStep;
            float _SpecularPower;
            float _Gloss;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 wPos : TEXCOORD1;
            };

            fixed4 simpleLight (fixed3 normal) {
                fixed3 lightDir = _WorldSpaceLightPos0.xyz;
                fixed3 lightCol = _LightColor0.rgb;
                //Lambert     
                fixed NdotL = max(dot(normal, lightDir),0);
                // Specular
                // fixed3 h = (lightDir - viewDirection) / 2;
                // fixed s = pow( dot(normal, h), _SpecularPower) * _Gloss;

                fixed4 c;
                c.rgb = _Color * NdotL;// lightCol * NdotL;// + s;
                c.a = 1;
                return c;
            }
 
            float map(float3 p)
            {
                return distance(p, _Center) - _Radius;
            }

            float3 normal (float3 p)
            {
                const float eps = 0.01;

                return normalize(
                    float3(	
                        map(p + float3(eps, 0, 0)	) - map(p - float3(eps, 0, 0)),
                        map(p + float3(0, eps, 0)	) - map(p - float3(0, eps, 0)),
                        map(p + float3(0, 0, eps)	) - map(p - float3(0, 0, eps))
                    )
                );
            }

            fixed4 renderSurface(float3 p)
            {
                float3 n = normal(p);
                return simpleLight(n);
            }

            fixed4 RayMarching(float3 position, float3 direction) {
                for(int i = 0; i < _MaxStep; i++) {
                    float distance = map(position);
                    if(distance < 0)
                        // return _Color;
                        return renderSurface(position);
                    position += _Step * direction;
                }
                return fixed4(1,1,1,0);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.wPos = mul(unity_ObjectToWorld, v.vertex).xyz; 
                return o;
            }

            fixed4 frag(v2f i) : SV_Target  
            {   
                float3 worldPos = i.wPos;
                float3 viewDirection = normalize(i.wPos - _WorldSpaceCameraPos);
                return RayMarching(worldPos, viewDirection);
            }

            ENDCG
        }
    }
}
