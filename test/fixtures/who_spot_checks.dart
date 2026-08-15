// GENERADO por tool/generate_reference.py — no editar a mano.
// Cortes SD publicados por la OMS, para verificar valueFromLms contra la fuente.

class WhoSpotCheck {
  const WhoSpotCheck(this.table, this.kind, this.sex, this.key,
      this.sd3neg, this.sd2neg, this.sd2, this.sd3, this.l, this.m, this.s);
  final String table, kind, sex;
  final double key, sd3neg, sd2neg, sd2, sd3, l, m, s;
}

const List<WhoSpotCheck> kWhoSpotChecks = [
  WhoSpotCheck('wfa_boys', 'weightForAge', 'boys', 365.0, 6.926, 7.741, 11.983, 13.341, 0.0645, 9.646, 0.10925),
  WhoSpotCheck('wfa_girls', 'weightForAge', 'girls', 365.0, 6.273, 7.041, 11.506, 13.114, -0.2022, 8.9462, 0.12267),
  WhoSpotCheck('lhfa_boys', 'statureForAge', 'boys', 365.0, 68.611, 70.987, 80.491, 82.867, 1.0, 75.7391, 0.03137),
  WhoSpotCheck('lhfa_girls', 'statureForAge', 'girls', 365.0, 66.281, 68.856, 79.154, 81.729, 1.0, 74.0049, 0.03479),
  WhoSpotCheck('wfl_boys', 'weightForStature', 'boys', 90.0, 10.092, 10.879, 15.011, 16.368, -0.3521, 12.7209, 0.08041),
  WhoSpotCheck('wfl_girls', 'weightForStature', 'girls', 90.0, 9.671, 10.498, 14.999, 16.533, -0.3833, 12.4723, 0.08906),
  WhoSpotCheck('wfh_boys', 'weightForStature', 'boys', 90.0, 10.226, 11.022, 15.204, 16.576, -0.3521, 12.8864, 0.08032),
  WhoSpotCheck('wfh_girls', 'weightForStature', 'girls', 90.0, 9.805, 10.644, 15.21, 16.767, -0.3833, 12.6461, 0.08911),
  WhoSpotCheck('bfa_boys', 'bmiForAge', 'boys', 365.0, 13.359, 14.385, 19.827, 21.635, -0.4113, 16.7992, 0.08009),
  WhoSpotCheck('bfa_girls', 'bmiForAge', 'girls', 365.0, 12.715, 13.794, 19.62, 21.591, -0.3665, 16.3578, 0.08797),
  WhoSpotCheck('hcfa_boys', 'headCircumferenceForAge', 'boys', 365.0, 42.21, 43.494, 48.633, 49.918, 1.0, 46.0637, 0.02789),
  WhoSpotCheck('hcfa_girls', 'headCircumferenceForAge', 'girls', 365.0, 40.817, 42.176, 47.612, 48.971, 1.0, 44.894, 0.03027),
];
