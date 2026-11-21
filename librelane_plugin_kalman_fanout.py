"""One post-CTS physical step; arithmetic RTL and timing constraints are unchanged."""
from pathlib import Path
from librelane.steps import Step
from librelane.steps.openroad import OpenROADStep
from librelane.steps.common_variables import dpl_variables


@Step.factory.register()
class ClockRootFanout(OpenROADStep):
    id = "Kalman.ClockRootFanout"
    name = "Clock Root Fanout"
    long_name = "Split overloaded clock and selected public input nets"
    config_vars = OpenROADStep.config_vars + dpl_variables

    def get_script_path(self):
        return str(Path(__file__).resolve().parent / "flow" / "clock_root_fanout.tcl")
