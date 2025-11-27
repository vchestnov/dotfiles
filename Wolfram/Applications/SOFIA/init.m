If[!ValueQ[SOFIAoptionFiniteFlow],
    SOFIAoptionFiniteFlow = False
];
If[!ValueQ[SOFIAoptionJulia],
    SOFIAoptionJulia = False
];
If[!ValueQ[SOFIAoptionEffortlessPath],
    SOFIAoptionEffortlessPath = ToFileName[$HomeDirectory, "soft/Effortless/Effortless.m"];
];
If[SameQ[SOFIAoptionJulia, False],
    Get @ ToFileName[$HomeDirectory, "soft/SOFIA/scr.m"]
,
    Get @ ToFileName[$HomeDirectory, "soft/SOFIA/scrj.m"]
];
