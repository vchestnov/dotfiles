{
    "soft/finiteflow",
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
    "dev/utils",
    "soft/amflow",
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
    Nothing
} // Map[RightComposition[
    ToFileName[$HomeDirectory, #]&,
    If[
        Not[MemberQ[$Path, #]],
        $Path = Flatten[{$Path, #}]
    ]&,
    Identity
]];
