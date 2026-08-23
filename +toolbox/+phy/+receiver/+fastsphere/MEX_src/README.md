# Compiling the fast_sphere MEX decoder

Fast sphere decoder can be compiled from the source code as follows:

```matlab
cd('+toolbox/+phy/+receiver/+fastsphere/MEX_src')
mex -O fast_sphere_decoder.cpp
movefile('fast_sphere_decoder.mex*', '..')
```

A C++ compiler must be registered with MATLAB first (`mex -setup C++`).

The optional `useQrAugmentation` input defaults to `true`. When enabled, the
decoder QR-factorizes `[H; sqrt(N0)*I]` and corrects complete-path metrics by
subtracting `N0*||x||^2`, preserving the original Euclidean ML distance.
