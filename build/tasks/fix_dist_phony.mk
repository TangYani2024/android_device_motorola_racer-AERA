# Ensure all dist goals collected in _all_dist_goals are marked .PHONY
# so ckati does not treat them as files in the readonly source tree when
# optional tool directories (such as tools/tradefederation/core) are omitted.
.PHONY: $(sort $(_all_dist_goals)) tradefed tradefed-core tradefed-all dist_files apps_only
