function analog_bf = build_analog_bf(cfg)
%BUILD_ANALOG_BF Build analog BF of size [m, n] for CDL where [m, n] = analogBF.arraySize.

m = cfg.channel.analogBF.arraySize(1);
n = cfg.channel.analogBF.arraySize(2);
az_deg_gcs = cfg.channel.analogBF.direction(1);
ze_deg_gcs = cfg.channel.analogBF.direction(2);
a = cfg.channel.transmitArrayOrientation(1);
b = cfg.channel.transmitArrayOrientation(2);
r = cfg.channel.transmitArrayOrientation(3);
dv = cfg.channel.transmitAntennaArray.elementSpacing(1);
dh = cfg.channel.transmitAntennaArray.elementSpacing(2);

localcoord = global2localcoord([az_deg_gcs; 90 - ze_deg_gcs; 1], 'ss', [0; 0; 0], rotz(a) * roty(b) * rotx(r));
az_deg_lcs = localcoord(1);
ze_deg_lcs = 90 - localcoord(2);

wv = exp(-2j * pi * dv * (0 : m - 1).' * cosd(ze_deg_lcs));
wh = exp(-2j * pi * dh * (0 : n - 1).' * sind(az_deg_lcs) * sind(ze_deg_lcs));
analog_bf = wv * wh.' / sqrt(m * n);
end
