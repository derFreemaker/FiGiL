return {
    Name = "Adapter.Pipeline",
    Namespace = "Adapter.Pipeline",
    Version = "0.1.0-45",
    PackageType = "Library",
    RequiredPackages = {
        "Core"
    },
    ModuleIndex={
        ["Adapter.Pipeline.Valve"] = {
            Location = "Adapter.Pipeline.Valve",
            Namespace = "Adapter.Pipeline.Valve",
            IsRunnable = true,
        },
    },
}
