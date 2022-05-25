from compass.testgroup import TestGroup
from compass.ocean.tests.dam_break.default import Default


class DamBreak(TestGroup):
    """
    A test group for dam break (wetting-and-drying) test cases
    """

    def __init__(self, mpas_core):
        """
        mpas_core : compass.MpasCore
            the MPAS core that this test group belongs to
        """
        super().__init__(mpas_core=mpas_core, name='dam_break')

        for resolution in [0.004, 0.012]:
            for coord_type in ['sigma']:
                self.add_test_case(
                    Default(test_group=self, resolution=resolution))
