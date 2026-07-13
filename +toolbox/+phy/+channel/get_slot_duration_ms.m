function slot_duration_ms = get_slot_duration_ms(subcarrier_spacing_khz)
%GETSLOTDURATIONMS Calculate slot duration in milliseconds.

mu = round(log2(subcarrier_spacing_khz / 15));
slot_duration_ms = 1 / (2^mu);
end
