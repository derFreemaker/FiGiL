﻿using CommandLine;

namespace Lua_Bundler
{
    internal class Program
    {
        private static void Main(string[] args)
        {
            ParserResult<BundlerConfigDataObject> parseResult = Parser.Default.ParseArguments<BundlerConfigDataObject>(args);
            if (parseResult.Tag == ParserResultType.NotParsed)
            {
                Environment.Exit(0);
            }

            var config = new BundlerConfig(parseResult.Value);

            var finder = new PackageFinder(config);

            var bundler = new Bundler(config, finder);

            bundler.Run();
        }
    }
}
