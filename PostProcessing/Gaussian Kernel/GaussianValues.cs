using UnityEngine;

/// <summary>
/// G : Gaussian Value     
/// S : Square Value
/// A : Accurate (σ=1이 아닌 K에 따라 계산됨)
/// </summary>
namespace Gaussian
{
    public static class GaussianValues
    {
        //float kernel5[5] = { 0.06136, 0.24477, 0.38774, 0.24477, 0.06136 };
        //float kernel7[7] = { 0.06136, 0.12183, 0.19445, 0.23213, 0.19445, 0.12183, 0.06136 };
        //float kernel9[9] = { 0.02702, 0.06136, 0.10377, 0.14676, 0.16191, 0.14676, 0.10377, 0.06136, 0.02702 };

        // Raw Gaussian Data (k = 2 * ceil(3 * σ) + 1):
        // k=5, σ=0.667: [0.011092, 0.325013, 1.000000, 0.325013, 0.011092], Sum=1.672210
        // k=7, σ=1.0: [0.011109, 0.135335, 0.606531, 1.000000, 0.606531, 0.135335, 0.011109], Sum=2.505950
        // k=9, σ=1.333: [0.011070, 0.079532, 0.325013, 0.754730, 1.000000, 0.754730, 0.325013, 0.079532, 0.011070], Sum=3.340690

        // k=k σ=1.0  : Raw값이 없음 => 이미 정규화됨

        // Raw Approximate Data:
        // k=5: [0.0625, 0.25, 0.375, 0.25, 0.0625], Sum=1.0s
        // k=7: [0.015625, 0.09375, 0.234375, 0.3125, 0.234375, 0.09375, 0.015625], Sum=1.0
        // k=9: [0.00390625, 0.03125, 0.109375, 0.21875, 0.2734375, 0.21875, 0.109375, 0.03125, 0.00390625], Sum=1.0

        public enum Kernel
        {
            K5, K7, K9
        }
        public enum Setting
        {
            GAR, GA, GR, G, SR, S
        }

        public struct Kernel9
        {
            public struct GAR
            {
                private const float N0 = 0.003f, N1 = 0.024f, N2 = 0.097f, N3 = 0.226f, N4 = 0.299f;
                private const float N5 = 0.226f, N6 = 0.097f, N7 = 0.024f, N8 = 0.003f;
                public static readonly float[] ToArray = { N0, N1, N2, N3, N4, N5, N6, N7, N8 };
            }
            public struct GA
            {
                private const float N0 = 0.003312f, N1 = 0.023809f, N2 = 0.097283f, N3 = 0.225928f, N4 = 0.299334f;
                private const float N5 = 0.225928f, N6 = 0.097283f, N7 = 0.023809f, N8 = 0.003312f;
                public static readonly float[] ToArray = { N0, N1, N2, N3, N4, N5, N6, N7, N8 };
            }
            public struct GR
            {
                private const float N0 = 0.001f, N1 = 0.004f, N2 = 0.054f, N3 = 0.242f, N4 = 0.398f;
                private const float N5 = 0.242f, N6 = 0.054f, N7 = 0.004f, N8 = 0.001f;
                public static readonly float[] ToArray = { N0, N1, N2, N3, N4, N5, N6, N7, N8 };
            }
            public struct G
            {
                private const float N0 = 0.000134f, N1 = 0.004432f, N2 = 0.054001f, N3 = 0.242022f, N4 = 0.399052f;
                private const float N5 = 0.242022f, N6 = 0.054001f, N7 = 0.004432f, N8 = 0.000134f;
                public static readonly float[] ToArray = { N0, N1, N2, N3, N4, N5, N6, N7, N8 };
            }
            public struct SR
            {
                private const float N0 = 0.004f, N1 = 0.031f, N2 = 0.109f, N3 = 0.219f, N4 = 0.273f;
                private const float N5 = 0.219f, N6 = 0.109f, N7 = 0.031f, N8 = 0.004f;
                public static readonly float[] ToArray = { N0, N1, N2, N3, N4, N5, N6, N7, N8 };
            }
            public struct S
            {
                private const float N0 = 0.00390625f, N1 = 0.03125f, N2 = 0.109375f, N3 = 0.21875f, N4 = 0.2734375f;
                private const float N5 = 0.21875f, N6 = 0.109375f, N7 = 0.03125f, N8 = 0.00390625f;
                public static readonly float[] ToArray = { N0, N1, N2, N3, N4, N5, N6, N7, N8 };
            }
        }

        public struct Kernel7
        {
            public struct GR
            {
                private const float N0 = 0.004f, N1 = 0.054f, N2 = 0.242f, N3 = 0.399f, N4 = 0.242f, N5 = 0.054f, N6 = 0.004f;
                public static readonly float[] ToArray = { N0, N1, N2, N3, N4, N5, N6 };
            }
            public struct G
            {
                private const float N0 = 0.004433f, N1 = 0.054012f, N2 = 0.241971f, N3 = 0.399168f, N4 = 0.241971f;
                private const float N5 = 0.054012f, N6 = 0.004433f;
                public static readonly float[] ToArray = { N0, N1, N2, N3, N4, N5, N6 };
            }
            public struct SR
            {
                private const float N0 = 0.016f, N1 = 0.094f, N2 = 0.234f, N3 = 0.313f, N4 = 0.234f, N5 = 0.094f, N6 = 0.016f;
                public static readonly float[] ToArray = { N0, N1, N2, N3, N4, N5, N6 };
            }
            public struct S
            {
                private const float N0 = 0.015625f, N1 = 0.09375f, N2 = 0.234375f, N3 = 0.3125f, N4 = 0.234375f;
                private const float N5 = 0.09375f, N6 = 0.015625f;
                public static readonly float[] ToArray = { N0, N1, N2, N3, N4, N5, N6 };
            }
        }

        public struct Kernel5
        {
            public struct GAR
            {
                private const float N0 = 0.007f, N1 = 0.194f, N2 = 0.598f, N3 = 0.194f, N4 = 0.007f;
                public static readonly float[] ToArray = { N0, N1, N2, N3, N4 };
            }
            public struct GA
            {
                private const float N0 = 0.006634f, N1 = 0.194384f, N2 = 0.597964f, N3 = 0.194384f, N4 = 0.006634f;
                public static readonly float[] ToArray = { N0, N1, N2, N3, N4 };
            }
            public struct GR
            {

                private const float N0 = 0.020f, N1 = 0.148f, N2 = 0.664f, N3 = 0.148f, N4 = 0.020f;
                public static readonly float[] ToArray = { N0, N1, N2, N3, N4 };
            }
            public struct G
            {
                private const float N0 = 0.020041f, N1 = 0.148153f, N2 = 0.663612f, N3 = 0.148153f, N4 = 0.020041f;
                public static readonly float[] ToArray = { N0, N1, N2, N3, N4 };
            }
            public struct SR
            {
                private const float N0 = 0.063f, N1 = 0.25f, N2 = 0.375f, N3 = 0.25f, N4 = 0.063f;
                public static readonly float[] ToArray = { N0, N1, N2, N3, N4 };
            }
            public struct S
            {
                private const float N0 = 0.0625f, N1 = 0.25f, N2 = 0.375f, N3 = 0.25f, N4 = 0.0625f;
                public static readonly float[] ToArray = { N0, N1, N2, N3, N4 };
            }
        }

        public static void GetKernel(Kernel kernel, Setting setting, out int k, out float[] array)
        {
            //균형
            (k, array) = kernel switch
            {
                Kernel.K5 => setting switch
                {
                    Setting.GA => (5, Kernel5.GA.ToArray),
                    Setting.G => (5, Kernel5.G.ToArray),
                    Setting.GAR => (5, Kernel5.GAR.ToArray),
                    Setting.GR => (5, Kernel5.GR.ToArray),
                    Setting.S => (5, Kernel5.S.ToArray),
                    Setting.SR => (5, Kernel5.SR.ToArray),
                    _ => (5, Kernel5.G.ToArray)
                },
                Kernel.K7 => setting switch
                {
                    Setting.GA | Setting.G => (7, Kernel7.G.ToArray),
                    Setting.GR  | Setting.GAR => (7, Kernel7.GR.ToArray),
                    Setting.S => (7, Kernel7.S.ToArray),
                    Setting.SR => (7, Kernel7.SR.ToArray),
                    _ => (7, Kernel7.G.ToArray)
                },
                Kernel.K9 => setting switch
                {
                    Setting.GA => (9, Kernel9.GA.ToArray),
                    Setting.G => (9, Kernel9.G.ToArray),
                    Setting.GAR => (9, Kernel9.GAR.ToArray),
                    Setting.GR => (9, Kernel9.GR.ToArray),
                    Setting.S => (9, Kernel9.S.ToArray),
                    Setting.SR => (9, Kernel9.SR.ToArray),
                    _ => (9, Kernel9.G.ToArray)
                },
                _ => (5, GaussianValues.Kernel5.G.ToArray)
            };
        }
    }
}

//Worst Case
/*
            (k, array) = (kernel, setting) switch
            {
                (Kernel.K5, Setting.G) => (5, Kernel5.G.ToArray),
                (Kernel.K5, Setting.GR) => (5, Kernel5.GR.ToArray),
                _ => (5, GaussianValues.Kernel5.G.ToArray),
            };
*/
