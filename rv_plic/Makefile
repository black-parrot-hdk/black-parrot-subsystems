.PHONY: all clean

OPENTITAN_DIR ?= ./import/opentitan

all:
	$(OPENTITAN_DIR)/util/ipgen.py generate -C $(OPENTITAN_DIR)/hw/ip_templates/rv_plic \
        -c rv_plic.ipconfig.hjson -o rv_plic/; mkdir -p v/ ;\
		mv rv_plic/rtl/* v/; rm -rf rv_plic/
	cp $(OPENTITAN_DIR)/hw/top_earlgrey/rtl/top_pkg.sv               v/
	cp $(OPENTITAN_DIR)/hw/ip/prim/rtl/prim_alert_pkg.sv             v/
	cp $(OPENTITAN_DIR)/hw/ip/prim/rtl/prim_secded_pkg.sv            v/
	cp $(OPENTITAN_DIR)/hw/ip/prim/rtl/prim_subreg_pkg.sv            v/
	cp $(OPENTITAN_DIR)/hw/ip/prim/rtl/prim_mubi_pkg.sv              v/
	cp $(OPENTITAN_DIR)/hw/ip/prim/rtl/prim_subreg.sv                v/
	cp $(OPENTITAN_DIR)/hw/ip/prim/rtl/prim_subreg_ext.sv            v/
	cp $(OPENTITAN_DIR)/hw/ip/prim/rtl/prim_alert_sender.sv          v/
	cp $(OPENTITAN_DIR)/hw/ip/prim/rtl/prim_secded_inv_64_57_dec.sv  v/
	cp $(OPENTITAN_DIR)/hw/ip/prim/rtl/prim_secded_inv_64_57_enc.sv  v/
	cp $(OPENTITAN_DIR)/hw/ip/prim/rtl/prim_sec_anchor_buf.sv        v/
	cp $(OPENTITAN_DIR)/hw/ip/prim/rtl/prim_sec_anchor_flop.sv       v/
	cp $(OPENTITAN_DIR)/hw/ip/prim/rtl/prim_diff_decode.sv           v/
	cp $(OPENTITAN_DIR)/hw/ip/prim/rtl/prim_secded_inv_39_32_enc.sv  v/
	cp $(OPENTITAN_DIR)/hw/ip/prim/rtl/prim_secded_inv_39_32_dec.sv  v/
	cp $(OPENTITAN_DIR)/hw/ip/tlul/rtl/tlul_pkg.sv                   v/
	cp $(OPENTITAN_DIR)/hw/ip/tlul/rtl/tlul_cmd_intg_gen.sv          v/
	cp $(OPENTITAN_DIR)/hw/ip/tlul/rtl/tlul_cmd_intg_chk.sv          v/
	cp $(OPENTITAN_DIR)/hw/ip/tlul/rtl/tlul_rsp_intg_chk.sv          v/
	cp $(OPENTITAN_DIR)/hw/ip/tlul/rtl/tlul_rsp_intg_gen.sv          v/
	cp $(OPENTITAN_DIR)/hw/ip/tlul/rtl/tlul_adapter_reg.sv           v/
	cp $(OPENTITAN_DIR)/hw/ip/tlul/rtl/tlul_err.sv                   v/
	cp $(OPENTITAN_DIR)/hw/ip/tlul/rtl/tlul_data_integ_enc.sv        v/
	cp $(OPENTITAN_DIR)/hw/ip/tlul/rtl/tlul_data_integ_dec.sv        v/
	cp $(OPENTITAN_DIR)/hw/ip/tlul/rtl/tlul_adapter_host.sv          v/
	cp $(OPENTITAN_DIR)/hw/ip/prim/rtl/prim_assert.sv                v/
	cp $(OPENTITAN_DIR)/hw/ip/prim/rtl/prim_assert_dummy_macros.svh  v/
	cp $(OPENTITAN_DIR)/hw/ip/prim/rtl/prim_subreg_arb.sv            v/
	cp $(OPENTITAN_DIR)/hw/ip/prim_generic/rtl/prim_generic_buf.sv        v/prim_buf.sv
	cp $(OPENTITAN_DIR)/hw/ip/prim_generic/rtl/prim_generic_flop_2sync.sv v/prim_flop_2sync.sv
	cp $(OPENTITAN_DIR)/hw/ip/prim_generic/rtl/prim_generic_flop.sv       v/prim_flop.sv
	git apply patch.txt

clean:
	rm -rf v/
