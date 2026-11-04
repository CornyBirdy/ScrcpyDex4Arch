// Copyright 2026 Aureliano Peixoto and ScrcpyDeX Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
using System;
using System.IO;
using System.Linq;

namespace ScrcpyDex.Core.Platform
{
    /// <summary>
    /// Minimal /etc/os-release reader used to choose distro-appropriate remediation hints.
    /// </summary>
    public static class LinuxDistro
    {
        private static readonly Lazy<string[]> Identifiers = new(ReadIdentifiers);

        /// <summary>True for Arch Linux and derivatives (EndeavourOS, Manjaro, CachyOS, ...).</summary>
        public static bool IsArchLike =>
            OperatingSystem.IsLinux() && Identifiers.Value.Contains("arch");

        /// <summary>Install command for VA-API video decoding drivers.</summary>
        public static string VaapiInstallCommand => IsArchLike
            ? "sudo pacman -S --needed libva-utils mesa intel-media-driver"
            : "sudo apt install va-driver-all i965-va-driver intel-media-va-driver vainfo mesa-va-drivers";

        /// <summary>Install command for the Android Debug Bridge.</summary>
        public static string AdbInstallCommand => IsArchLike
            ? "sudo pacman -S --needed android-tools"
            : "sudo apt install adb";

        private static string[] ReadIdentifiers()
        {
            try
            {
                const string path = "/etc/os-release";
                if (!File.Exists(path))
                {
                    return Array.Empty<string>();
                }

                var ids = new System.Collections.Generic.List<string>();
                foreach (var line in File.ReadLines(path))
                {
                    if (line.StartsWith("ID=", StringComparison.Ordinal) ||
                        line.StartsWith("ID_LIKE=", StringComparison.Ordinal))
                    {
                        var value = line.Substring(line.IndexOf('=') + 1).Trim().Trim('"', '\'');
                        ids.AddRange(value.Split(' ', StringSplitOptions.RemoveEmptyEntries));
                    }
                }
                return ids.Select(i => i.ToLowerInvariant()).ToArray();
            }
            catch
            {
                return Array.Empty<string>();
            }
        }
    }
}
