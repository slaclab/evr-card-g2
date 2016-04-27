## LLR - 27APRIL2016
## After generating each of the .DCP files from their corresponding .XCI files, 
## performed the following TCL commands in the DCP to generate a modified DCP file:

# Changed TXDIFFCTRL from "1100" to "1111"
disconnect_net -prune -net [get_nets U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[3].gt_wrapper_i/<const0>] -objects [get_pins U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[3].gt_wrapper_i/gtx_channel.gtxe2_channel_i/TXDIFFCTRL[0]]
disconnect_net -prune -net [get_nets U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[3].gt_wrapper_i/<const0>] -objects [get_pins U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[3].gt_wrapper_i/gtx_channel.gtxe2_channel_i/TXDIFFCTRL[1]]
disconnect_net -prune -net [get_nets U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[2].gt_wrapper_i/<const0>] -objects [get_pins U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[2].gt_wrapper_i/gtx_channel.gtxe2_channel_i/TXDIFFCTRL[0]]
disconnect_net -prune -net [get_nets U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[2].gt_wrapper_i/<const0>] -objects [get_pins U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[2].gt_wrapper_i/gtx_channel.gtxe2_channel_i/TXDIFFCTRL[1]]
disconnect_net -prune -net [get_nets U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[1].gt_wrapper_i/<const0>] -objects [get_pins U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[1].gt_wrapper_i/gtx_channel.gtxe2_channel_i/TXDIFFCTRL[0]]
disconnect_net -prune -net [get_nets U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[1].gt_wrapper_i/<const0>] -objects [get_pins U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[1].gt_wrapper_i/gtx_channel.gtxe2_channel_i/TXDIFFCTRL[1]]
disconnect_net -prune -net [get_nets U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/<const0>] -objects [get_pins U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtx_channel.gtxe2_channel_i/TXDIFFCTRL[0]]
disconnect_net -prune -net [get_nets U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/<const0>] -objects [get_pins U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtx_channel.gtxe2_channel_i/TXDIFFCTRL[1]]

connect_net -net [get_nets U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[3].gt_wrapper_i/<const1>] -objects [get_pins U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[3].gt_wrapper_i/gtx_channel.gtxe2_channel_i/TXDIFFCTRL[0]]
connect_net -net [get_nets U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[3].gt_wrapper_i/<const1>] -objects [get_pins U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[3].gt_wrapper_i/gtx_channel.gtxe2_channel_i/TXDIFFCTRL[1]]
connect_net -net [get_nets U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[2].gt_wrapper_i/<const1>] -objects [get_pins U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[2].gt_wrapper_i/gtx_channel.gtxe2_channel_i/TXDIFFCTRL[0]]
connect_net -net [get_nets U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[2].gt_wrapper_i/<const1>] -objects [get_pins U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[2].gt_wrapper_i/gtx_channel.gtxe2_channel_i/TXDIFFCTRL[1]]
connect_net -net [get_nets U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[1].gt_wrapper_i/<const1>] -objects [get_pins U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[1].gt_wrapper_i/gtx_channel.gtxe2_channel_i/TXDIFFCTRL[0]]
connect_net -net [get_nets U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[1].gt_wrapper_i/<const1>] -objects [get_pins U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[1].gt_wrapper_i/gtx_channel.gtxe2_channel_i/TXDIFFCTRL[1]]
connect_net -net [get_nets U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/<const1>] -objects [get_pins U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtx_channel.gtxe2_channel_i/TXDIFFCTRL[0]]
connect_net -net [get_nets U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/<const1>] -objects [get_pins U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtx_channel.gtxe2_channel_i/TXDIFFCTRL[1]]

#Note: Vivado doesn't automatically recongize disconnect and connect operations as requiring to have.  You will have to do this manually:
#      Example: write_checkpoint -force I:/projects/LCLS_II/EvrCardG2/firmware/modules/LegacyCommon/pci/coregen/EvrCardG2PciIpCore