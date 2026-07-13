function [carrier, pdsch] = build_link_objects(cfg, mcs_info)
%BUILDLINKOBJECTS Create carrier and PDSCH configuration objects.

carrier = nrCarrierConfig;
carrier.NSizeGrid = cfg.carrier.nSizeGrid;
carrier.SubcarrierSpacing = cfg.carrier.subcarrierSpacingKHz;
carrier.CyclicPrefix = cfg.carrier.cyclicPrefix;
carrier.NCellID = cfg.carrier.nCellId;
carrier.NSlot = 0;

pdsch = nrPDSCHConfig;
pdsch.Modulation = mcs_info.modulation;
pdsch.NumLayers = cfg.pdsch.numLayers;
pdsch.MappingType = cfg.pdsch.mappingType;
pdsch.SymbolAllocation = cfg.pdsch.symbolAllocation;
pdsch.PRBSet = cfg.pdsch.prbSet;
pdsch.RNTI = cfg.pdsch.rnti;
pdsch.NID = cfg.pdsch.nId;

pdsch.DMRS.DMRSConfigurationType = cfg.pdsch.dmrs.configurationType;
pdsch.DMRS.DMRSTypeAPosition = cfg.pdsch.dmrs.typeAPosition;
pdsch.DMRS.DMRSLength = cfg.pdsch.dmrs.length;
pdsch.DMRS.DMRSAdditionalPosition = cfg.pdsch.dmrs.additionalPosition;
pdsch.DMRS.NumCDMGroupsWithoutData = ...
    cfg.pdsch.dmrs.numCDMGroupsWithoutData;
end
