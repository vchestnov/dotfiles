{
    ".local/lib/",
    ".local/lib/finiteflow32/mathematica",
    Nothing
} // Map[RightComposition[
    ToFileName[$HomeDirectory, #]&,
    If[
        Not[MemberQ[$LibraryPath, #]],
        $LibraryPath = Flatten[{$LibraryPath, #}]
    ]&,
    Identity
]];

{
    "dev/finiteflow/mathlink",
    ".local/share/finiteflow32/mathematica",
    "dev/utils",
    "soft/amflow",
    "soft/azurite/code",
    "soft/Baikovletter",
    "soft/BaikovPackage",
    "soft/calcloop",
    "soft/calico",
    "soft/DlogBasis",
    (* "soft/Fermatica/source", *)
    "soft/ff_ext_packages/packages",
    "soft/finiteflow-mathtools/packages",
    "soft/ff_feyntools/packages",
    "soft/INITIAL",
    (* "soft/Libra/Source", *)
    (* "soft/LiteRed2/Source", *)
    "soft/NeatIBP",
    "soft/rationalizeroots",
    "soft/Effortless",
    "dev/spqr/landau/math/codes",
    "soft/Singular",
    "soft/MultivariateApart",
    "soft/Subtropica",
    "soft/blade",
    "soft/Canonica/src",
    "dev/Euler_Methods",
    "soft/HyperPrecision",
    Nothing
} // Map[RightComposition[
    ToFileName[$HomeDirectory, #]&,
    If[
        Not[MemberQ[$Path, #]],
        $Path = Flatten[{$Path, #}]
    ]&,
    Identity
]];

finiteFlow32Prefix = FileNameJoin[{$HomeDirectory, ".local"}];
finiteFlow32Msolve = FileNameJoin[{finiteFlow32Prefix, "bin", "msolve"}];
finiteFlow32Worker = FileNameJoin[{finiteFlow32Prefix, "bin", "finiteflow32-msolve-worker"}];

SetEnvironment["FINITEFLOW32_PREFIX" -> finiteFlow32Prefix];

If[FileExistsQ[finiteFlow32Msolve],
    SetEnvironment["MSOLVE" -> finiteFlow32Msolve]
];

If[FileExistsQ[finiteFlow32Worker],
    SetEnvironment["FINITEFLOW32_MSOLVE_WORKER" -> finiteFlow32Worker]
];

Clear[finiteFlow32Prefix, finiteFlow32Msolve, finiteFlow32Worker];
