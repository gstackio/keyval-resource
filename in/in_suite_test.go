package main_test

import (
	"os"
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/onsi/gomega/gexec"
)

var inPath string

var _ = BeforeSuite(func() {
	var err error

	if _, err = os.Stat("/opt/resource/in"); err == nil {
		inPath = "/opt/resource/in"
	} else {
		inPath, err = gexec.Build("gstack.io/concourse/keyval-resource/in")
		Expect(err).NotTo(HaveOccurred())
	}
})

var _ = AfterSuite(func() {
	gexec.CleanupBuildArtifacts()
})

func TestIn(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "In Suite")
}
