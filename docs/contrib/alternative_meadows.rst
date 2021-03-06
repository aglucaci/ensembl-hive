
.. _other-job-schedulers:

Other job schedulers
====================

eHive has a generic interface named :ref:`Meadow <meadows-overview>`
that describes how to interact with an underlying grid scheduler
(submit jobs, query job's status, etc.).  eHive is distributed with
two meadow implementations:

LOCAL
  A simple meadow that submits jobs locally via ``system()`` (i.e. ``fork()``).
  It is inherently limited by the specification of the machine Beekeeper is
  running on.
  The implementation is not able to control the memory consumption of the
  jobs vs the memory available. All jobs are supposed to be using one core
  each, and the total number of jobs is limited by (i) a machine-specific
  configuration found in the ``hive_config.json`` file and (ii) the
  *analysis_capacity* and *hive_capacity* mechanisms.

LSF
  A meadow that supports `IBM Platform LSF <http://www-03.ibm.com/systems/spectrum-computing/products/lsf/>`__
  This meadow is extensively used by the Ensembl project and is regularly
  updated. It is fully implemented and supports workloads reaching
  thousands of parallel jobs.

Other meadows have been contributed to the project, though sometimes not
all the features are implemented.  Being developed outside of the main
codebase, they may be at times out of sync with the latest version of
eHive.  Nevertheless, several are continuously tested on `Travis CI
<https://travis-ci.org/Ensembl>`__ using single-machine Docker
installations. Refer to the documentation or README in each of those
repositories to know more about their compatibility and support.

SGE
  A meadow that supports Sun Grid Engine (now known as Oracle Grid Engine). Available for download on GitHub at `Ensembl/ensembl-hive-sge <https://github.com/Ensembl/ensembl-hive-sge>`__.

HTCondor
  A meadow that supports `HTCondor <https://research.cs.wisc.edu/htcondor/>`__. Available for download on GitHub at `Ensembl/ensembl-hive-htcondor <https://github.com/Ensembl/ensembl-hive-htcondor>`__.

PBSPro
  A meadow that supports `PBS Pro <http://www.pbspro.org>`__. Available for download on GitHub at `Ensembl/ensembl-hive-pbspro <https://github.com/Ensembl/ensembl-hive-pbspro>`__.

SLURM
  A meadow that supports `Slurm <https://slurm.schedmd.com/>`__. Available for download on GitHub at `tweep/ensembl-hive-slurm <https://github.com/tweep/ensembl-hive-slurm>`__.

DockerSwarm
  A meadow that can control and run on `Docker Swarm <https://docs.docker.com/engine/swarm/>`__.
  Available for download on GitHub at
  `Ensembl/ensembl-hive-docker-swarm <https://github.com/Ensembl/ensembl-hive-docker-swarm>`__.
  See :ref:`docker-swarm-intro` for more information.


The table below lists the capabilities of each meadow, and whether they are available and implemented:

.. list-table::
   :header-rows: 1

   * - Meadow
     - Submit jobs
     - Query job status
     - Kill job
     - Job limiter and resource management
     - Post-mortem inspection of resource usage
   * - LOCAL
     - Yes
     - Yes
     - Yes
     - Partially implemented
     - Not available
   * - LSF
     - Yes
     - Yes
     - Yes
     - Yes
     - Yes
   * - SGE
     - Yes
     - Yes
     - Yes
     - Yes
     - Not implemented
   * - HTCondor
     - Yes
     - Yes
     - Yes
     - Yes
     - Not implemented
   * - PBSPro
     - Yes
     - Yes
     - Yes
     - Yes
     - Not implemented
   * - SLURM
     - Yes
     - Yes
     - Yes
     - Yes
     - Yes
   * - DockerSwarm
     - Yes
     - Yes
     - Not implemented
     - Yes
     - Not implemented

