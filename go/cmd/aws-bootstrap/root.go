package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var (
	cfgFile string
	version = "2.0.0-alpha"
)

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "aws-bootstrap",
	Short: "AWS Multi-Account Bootstrap with GitHub CI/CD",
	Long: `AWS Multi-Account Bootstrap - Create production-ready AWS infrastructure

A tool to automate the creation of a multi-account AWS setup with GitHub Actions CI/CD.
Creates Dev, Staging, and Prod environments with OIDC authentication, billing alerts,
and CDK bootstrap in one command.

Features:
  • Interactive TUI wizard with beautiful terminal UI
  • Non-interactive mode for CI/CD automation
  • Cost estimation before creating resources
  • Dry-run mode to preview changes
  • Configuration via files, environment variables, or flags`,
	Version: version,
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() error {
	return rootCmd.Execute()
}

func init() {
	cobra.OnInitialize(initConfig)

	// Global flags
	rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is ./aws-bootstrap.yaml)")
	rootCmd.PersistentFlags().Bool("json", false, "output in JSON format")
	rootCmd.PersistentFlags().Bool("verbose", false, "verbose output")

	// Bind flags to viper
	viper.BindPFlag("json", rootCmd.PersistentFlags().Lookup("json"))
	viper.BindPFlag("verbose", rootCmd.PersistentFlags().Lookup("verbose"))
}

// initConfig reads in config file and ENV variables if set.
func initConfig() {
	if cfgFile != "" {
		// Use config file from the flag
		viper.SetConfigFile(cfgFile)
	} else {
		// Search for config in current directory
		viper.AddConfigPath(".")
		viper.SetConfigType("yaml")
		viper.SetConfigName("aws-bootstrap")
	}

	// Read in environment variables that match
	viper.SetEnvPrefix("AWS_BOOTSTRAP")
	viper.AutomaticEnv()

	// If a config file is found, read it in
	if err := viper.ReadInConfig(); err == nil {
		if viper.GetBool("verbose") {
			fmt.Fprintln(os.Stderr, "Using config file:", viper.ConfigFileUsed())
		}
	}
}
