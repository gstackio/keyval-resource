
[![Docker Stars](https://img.shields.io/docker/stars/gstack/keyval-resource.svg?style=plastic)](https://registry.hub.docker.com/v2/repositories/gstack/keyval-resource/stars/count/)
[![Docker pulls](https://img.shields.io/docker/pulls/gstack/keyval-resource.svg?style=plastic)](https://registry.hub.docker.com/v2/repositories/gstack/keyval-resource)
<!--
[![Concourse Build](https://ci.gstack.io/api/v1/teams/gk-plat-devs/pipelines/keyval-resource/jobs/build/badge)](https://ci.gstack.io/teams/gk-plat-devs/pipelines/keyval-resource)
-->
[![dockeri.co](https://dockeri.co/image/gstack/keyval-resource)](https://hub.docker.com/r/gstack/keyval-resource/)

# Concourse key-value resource

Implements a resource that passes sets of key-value pairs between jobs without
using any external storage with resource like [Git][git_resource] or
[S3][s3_resource].

Pulled by a `get` step, key-value pairs are provided to the build plan as an
artifact directory with one file per key-value pair. The name of a file is
the “key”, and its contents is the “value”. These key-value pairs can then be
loaded as local build vars using a [`load_var` step][load_var_step].

Pushed by a `put` step, key-value pairs are persisted in the Concourse SQL
database. For this to be possible, the trick is that they are serialized as
keys and values in [`version` JSON objects][version_schema]. As such, they
are designed to hold _small_, _textual_, _non-secret_ data.

In case you're dealing with large text, binary data or secrets, we recommend
you opt for other solutions. Indeed, secrets will be best stored in a vault
like [CredHub][credhub], large text files in [Git][git_resource], and binary
data in some [object storage][s3_resource] or [Git][git_resource] with
Git-LFS, the “[Large File Storage][git_lfs]” addon.

[git_resource]: https://github.com/concourse/git-resource
[s3_resource]: https://github.com/concourse/s3-resource
[load_var_step]: https://concourse-ci.org/load-var-step.html
[version_schema]: https://concourse-ci.org/config-basics.html#schema.version
[git_lfs]: https://git-lfs.com/
[credhub]: https://github.com/pivotal/credhub-release



## Credits

This resource is a fork of the [`keyval` resource][moredhel_gh] by
[@moredhel](https://github.com/moredhel).

Compared to the [original `keyval` resource][swce_gh] from SWCE by
[@regevbr](https://github.com/regevbr) and [@ezraroi](https://github.com/ezraroi),
writing key-value pairs as plain files in some resource folder is more
consistent with usual conventions in Concourse, when it comes to storing
anything in step artifacts. It is also compliant with the ConfigMap pattern
from Kubernetes.

Writing/reading files is always easier in Bash scripts than parsing some Java
Properties file, because much less boilerplate code is required.

[moredhel_gh]: https://github.com/moredhel/keyval-resource
[swce_gh]: https://github.com/SWCE/keyval-resource



## Source Configuration

```yaml
resource_types:
  - name: key-value
    type: registry-image
    source:
      repository: gstack/keyval-resource

resources:
  - name: key-value
    type: key-value
```

#### Parameters

- `history_identifier`: _Optional._
  When the [“global resources” feature][gbl_rsc_docs] is enabled on your
  Concourse installation, and you don't want a single resource history for all
  the keyval resources defined in your Concourse installation, then set this
  property to a relevant identifier, possibly unique or not. See the
  [“global resources” section](#discussion-on-global-resources) for a detailed
  discussion on use-cases and solutions.

[gbl_rsc_docs]: https://concourse-ci.org/global-resources.html

## Behavior

### `check` Step (`check` script): Report the latest stored key-value pairs

This is a version-less resource so `check` behavior is no-op.

It will detect the latest store key/value pairs, if any, and won't provide any
version history.

#### Parameters

*None.*

### `get` Step (`in` script): Fetch the latest stored key-value pairs from the Concourse SQL database

Fetches the given key & values from the stored resource version JSON (in the
Concourse SQL database) and write them in their respective files where the
key is the file name and the value is the file contents.

```json
"version": { "some_key": "some_value" }
```

would result in:

```bash
$ cat resource/some_key
some_value
```

#### Parameters

*None.*

### `put` Step (`out` script): Store new set of key-value pairs to the Concourse SQL database

Converts each file in the artifact directory designated by `directory` to a
set of key-value pairs, where file names are the keys and file contents are
the values. This set of key-value pairs is persisted in the `version` JSON
object, to be stored in the Concourse SQL database.

A value from a file in `directory` can be overridden by a matching key with
different value in the dictionary given as the `overrides` parameter. If you
need to store some Concourse `((vars))` value in a key-value resource, then
add it to the `overrides` parameter of some `put` step.

#### Parameters

- `directory`: *Required.* The artifact directory to be scanned for files, in
  order to generate key-value pairs

- `overrides`: *Optional.* A dictionary of key-value pairs that will override
  any matching pair with same key found in `directory`.



## Examples

### Summarized example

This example make intentional ellipsis in order to focus on the main ideas
behind the “keyval” resource. Seasoned Concourse practitioners can find an
illustration here in one catch.

```yaml
resource_types:
  - name: key-value
    type: registry-image
    source:
      repository: gstack/keyval-resource

resources:
  - name: build-info
    type: key-value

jobs:

  - name: build
    plan:
      - task: build
        file: tools/tasks/build/task.yml # <- must declare a 'build-info' output artifact
      - put: build-info
        params:
          directory: build-info

  - name: test-deploy
    plan:
      - in_parallel:
          - get: build-info
            passed: [ build ]
      - task: test-deploy
        file: tools/tasks/task.yml # <- must declare a 'build-info' input artifact
```

The `build` task writes all the key-value pairs it needs to pass along in
files inside the `build-info` output artifact directory.

The `test-deploy` job then reads the files from the `build-info` resource,
which produces a `build-info` artifact directory to be used by the
`test-deploy` task.


### Detailed example

This fully-working and detailed example goes deeper in showcasing what the
resource can actually do and how. Concourse beginners are recommended to read
this as it details very clearly the relation between resource, artifact
directories, and tasks.

```yaml
resource_types:
  - name: key-value
    type: registry-image
    source: { repository: gstack/keyval-resource }

resources:
  - name: some-keyval-resource
    type: key-value
  - name: runner-image
    type: registry-image
    source: { repository: busybox }

jobs:
  - name: step-1-job
    plan:
      - get: runner-image
      - task: write-keyval-aaa-1-task
        image: runner-image
        config:
          platform: linux
          outputs: [ { name: created-keyvals-artifact } ]
          run:
            path: sh
            args:
              - -exc
              - |
                echo "1" > created-keyvals-artifact/aaa
      - put: some-keyval-resource
        params:
          directory: created-keyvals-artifact
  - name: step-2-job
    plan:
      - in_parallel:
          - get: keyvals-artifact          # here artifact directory is
            resource: some-keyval-resource # different from resource name
            trigger: true
            passed: [ step-1-job ]
          - get: runner-image
      - task: read-aaa-keyval-task
        image: runner-image
        config:
          platform: linux
          inputs: [ { name: keyvals-artifact } ]
          run:
            path: sh
            args:
              - -exc
              - |
                cat keyvals-artifact/aaa  # -> 1
      - task: write-bbb-keyval-task
        image: runner-image
        config:
          platform: linux
          inputs:  [ { name: keyvals-artifact } ]
          outputs: [ { name: keyvals-artifact } ]
          run:
            path: sh
            args:
              - -exc
              - |
                echo "2" > build-info/bbb
      - put: some-keyval-resource
        params:
          directory: keyvals-artifact
          overrides:
            aaa: "11"
            ccc: "3"
  - name: step-3-job
    plan:
      - in_parallel:
          - get: some-keyval-resource # artifact dir will have same name
            trigger: true
            passed: [ step-2-job ]
          - get: runner-image
      - task: read-aaa-bbb-ccc-keyvals-task
        image: runner-image
        config:
          platform: linux
          inputs: [ { name: some-keyval-resource } ]
          run:
            path: sh
            args:
              - -exc
              - |
                cat build-info/aaa  # -> 11
                cat build-info/bbb  # -> 2
                cat build-info/ccc  # -> 3
```

The `write-keyval-aaa-1-task` creates a file named `aaa` with content `1` to
the `created-keyvals-artifact` output artifact directory. The
`some-keyval-resource` resource will read files in the
`created-keyvals-artifact` directory and store a key-value pair `
{"aaa": "1"}`.

The `read-aaa-keyval-task` reads the value from the `aaa` file in
`keyvals-artifact` input artifact directory provided from the
`some-keyval-resource` resource. This outputs `1`.

The `write-bbb-keyval-task` creates a file named `bbb` with content `2` to
`keyvals-artifact` output artifact directory. Because this directory is same
as `keyvals-artifact` input artifact directory which already contains `aaa`.
The `some-keyval-resource` resource will read all files in the
`keyvals-artifact` directory and store key-value pairs `{"aaa": "1"}` and `
{"bbb": "2"}`.

The `put: some-keyval-resource` in `step-2-job` provides the `overrides`
option, which changes the original key-value pair `{"aaa": "1"}` to `
{"aaa": "11"}` and add a new pair `{"ccc": "3"}`.

The `read-aaa-bbb-ccc-keyvals-task` reads values from files in the
`some-keyval-resource` input artifact directory, as provided by the
`some-keyval-resource` resource.



## Discussion on “global resources”

When the “[global resources][gbl_rsc_docs]” feature is enabled, all resources
with same `resource.type` and `resource.source` configuration will share the
same version history. If you leave the `resource.source` configuration blank
in all your keyval resources, then they will _all_ be considered the exact
same resource by Concourse, sharing the exact same history.

For most keyval resource-related use-case though, this is not releavant and
thus requires proper scoping.

### Scenario #1: pipeline-private key-values

In many scearios, the key-value resources is used to transmit
pipeline-specific data between jobs of the same pipeline. In such case,
sharing resource history is most probably irrelevant. In order to avoid this,
you can set the `history_identifier` to some value that will be unique in your
Concourse installation.

For best portability of your pipeline across different Concourse
installations, we recommend that you use a UUID that can be generated with the
`uuidgen` command-line tool like this:

```shell
$ uuidgen | tr [:upper:] [:lower:]
fc4cb2ba-d0d4-44e2-8589-8fa89a8271fd
```

Then use it in the resource configuration, so that the resource history is
scoped privately:

```yaml
resources:
  - name: key-value
    type: key-value
    source:
      history_identifier: fc4cb2ba-d0d4-44e2-8589-8fa89a8271fd
```

### Scenario #2: shared key-values between pipelines

In some scenarios though, it may be interesting to share the resources history
between different pipelines. Then you can leverage key-value resources that
share the same `history_identifier` value.

As a result, as soon as a new version is pushed on the shared key-value
resources, all other pipelines will see it.

#### Example use-case: triggering other pipelines

This is interesting in case some pipeline has to trigger other pipelines. A
usual solution is to use a “dummy” `semver` resource, backed by Git or some
object storage.

Using the keyval resource can bring an elegant alternative. A limitation is
that this resource basically has no version history. At every point in time,
only the last vesion exisits for the resource. This is not an issue for this
use-case, though. Indeed with a “dummy” `semver` resource, experience shows
that nobody actually pays attention to the version history anyway.

With the keyval resource, the triggering version only need to specify the date
and relevant data showing the reason why the pipeline has been triggered.
These will appear and properly stay in job build logs, for later inspection.



## Migrating from previous key-value resources

### Migrating from `SWCE/keyval-resource`

Key-value pairs are no more written as Java `.properties` file, but rather one
file per key-value pair. The name of a file is a “key”, and its contents is
the related “value”.

The required `file` paramerter for `put` steps is replaced by `directory`.

### Migrating from `moredhel/keyval-resource`

The required `directory` paramerter has been added to `put` steps.

The `file` parameter of `put` steps is renamed `overrides`.



<!-- START_OF_DOCKERHUB_STRIP -->

## Development

### Running the tests

Golang unit tests can be run from some shell command-line with Ginkgo, that
has [to be installed](https://github.com/onsi/ginkgo#getting-started) first.

```bash
make test
```

These unit test are embedded in the `Dockerfile`, ensuring they are
consistently run in a determined Docker image providing proper test
environment. Whenever the tests fail the Docker build will be stopped.

In order to build the image and run the unit tests, use `docker build` as
follows:

```bash
docker build -t keyval-resource .
```

### Contributing

Please make all pull requests to the `master` branch and ensure tests pass
locally.

When submitting a Pull Request or pushing new commits, the Concourse CI/CD
pipeline provides feedback with building the Dockerfile, which implies
running Ginkgo unit tests.

<!-- END_OF_DOCKERHUB_STRIP -->



## Author and license

Copyright © 2021-present, Benjamin Gandon, Gstack

Like Concourse, the key-value resource is released under the terms of the
[Apache 2.0 license](http://www.apache.org/licenses/LICENSE-2.0).

<!--
# Local Variables:
# indent-tabs-mode: nil
# End:
-->
