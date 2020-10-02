// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'



Shader "Custom/01VolRender"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Radius ("Radius", float) = 1
        _Centre ("Centre", float) = 0
    }
    SubShader
    {
        // No culling or depth
        // Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float _Radius;
            float _Centre;

            #define STEPS 64
            #define STEP_SIZE 0.1
            
            struct appdata
            {
                float4 vertex : POSITION;
                // float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                // float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION; // Clip space
                float3 wPos : TEXCOORD1; // World position
            };

            v2f vert (appdata v)
            {
                v2f o;
                // o.vertex = UnityObjectToClipPos(v.vertex);
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.wPos = mul(unity_ObjectToWorld, v.vertex).xyz; 
                // o.uv = v.uv;
                return o;
            }

            

            bool sphereHit (float3 p)
            {
                return distance(p,_Centre) < _Radius;
            }

            bool raymarchHit (float3 position, float3 direction)
            {
                for (int i = 0; i < STEPS; i++)
                {
                    if ( sphereHit(position) )
                        return true;
            
                    position += direction * STEP_SIZE;
                }
            
                return false;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 worldPosition = i.wPos;
                float3 viewDirection = normalize(i.wPos - _WorldSpaceCameraPos);
                if ( raymarchHit(worldPosition, viewDirection) )
                {
                return fixed4(1,0,0,1); // Red if hit the ball

                }
                else{
                return fixed4(1,1,1,1); // White otherwise
                }
            }
            ENDCG
        }
    }
}
