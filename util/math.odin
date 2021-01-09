package util

nvec :: proc($N: int, v: [$M]$E) -> [N]E
{
    ret: [N]E;
    for i in 0..<(min(N, M)) do ret[i] = v[i];
    return ret;
}