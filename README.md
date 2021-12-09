
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

In terms of pipeline design, secrets are supposed to be stored in a vault like
CredHub instead, and binaries or large text files are supposed to be stored
on more relevant persistent storage like [Git][git_resource] (possibly with
Git-LFS) or [S3][s3_resource].

[git_resource]: https://github.com/concourse/git-resource
[s3_resource]: https://github.com/concourse/s3-resource
[load_var_step]: https://concourse-ci.org/load-var-step.html
[version_schema]: https://concourse-ci.org/config-basics.html#schema.version



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

``` YAML
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

*None.*



## Behavior

### `check`: Report the latest stored key-value pairs

This is a version-less resource so `check` behavior is no-op.

It will detect the latest store key/value pairs, if any, and won't provide any
version history.

#### Parameters

*None.*

### `in`: Fetch the latest stored key-value pairs from the Concourse SQL database

Fetches the given key & values from the stored resource version JSON (in the
Concourse SQL database) and write them in their respective files where the
key is the file name and the value is the file contents.

```json
"version": { "some_key": "some_value" }
```

would result in:

```
$ cat resource/some_key
some_value
```

#### Parameters

*None.*

### `out`: Store new set of key-value pairs to the Concourse SQL database

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



## Author and License

Copyright © 2021-present, Benjamin Gandon, Gstack

Like Concourse, the key-value resource is released under the terms of the
[Apache 2.0 license](http://www.apache.org/licenses/LICENSE-2.0).

<!--
# Local Variables:
# indent-tabs-mode: nil
# End:
-->
