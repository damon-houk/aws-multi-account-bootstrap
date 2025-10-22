package main

import (
	"fmt"
	"runtime"

	"github.com/spf13/cobra"
)

var (
	// These will be set by build flags
	gitCommit = "dev"
	buildDate = "unknown"
)

// versionCmd represents the version command
var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Show version information",
	Long:  `Display version, build information, and Go runtime details.`,
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("aws-bootstrap version %s\n", version)
		fmt.Printf("Git commit: %s\n", gitCommit)
		fmt.Printf("Built: %s\n", buildDate)
		fmt.Printf("Go version: %s\n", runtime.Version())
		fmt.Printf("OS/Arch: %s/%s\n", runtime.GOOS, runtime.GOARCH)
	},
}

func init() {
	rootCmd.AddCommand(versionCmd)
}
