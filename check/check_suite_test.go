package main_test

import (
	"os"
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

var checkPath string

var _ = BeforeSuite(func() {
	var err error

	if _, err = os.Stat("/opt/resource/check"); err == nil {
		checkPath = "/opt/resource/check"
	} else {
		checkPath, err = gexec.Build("gstack.io/concourse/keyval-resource/check")
		Expect(err).NotTo(HaveOccurred())
	}
})

var _ = AfterSuite(func() {
	gexec.CleanupBuildArtifacts()
})

func TestCheck(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Check Suite")
}
