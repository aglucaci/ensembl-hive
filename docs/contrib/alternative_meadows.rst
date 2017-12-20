
Other job schedulers
====================

eHive has a generic interface named *Meadow* that describes how to interact
with an underlying grid scheduler (submit jobs, query job's status, etc).
eHive ships some meadow implementations:

LOCAL
  A simple meadow that submits jobs locally via ``system()`` (i.e. ``fork()``).
  It is inherently limited by the specification of the machine beekeeper is
  running on.
  The implementation is not able to control the memory consumption of the
  jobs vs the memory available. All jobs are supposed to be using 1 core
  each, and the total number of jobs is limited by the analysis_capacity
  and hive_capacity mechanisms.

LSF
  A meadow that supports `IBM Platform LSF <http://www-03.ibm.com/systems/spectrum-computing/products/lsf/>`__
  This meadow is extensively used by the Ensembl project and is regularly
  updated. It is fully implemented and supports workloads reaching
  thousands of parallel jobs.

Other meadows have been contributed to the project but their support is
more limited. Not all the features may be implemented (by lack of
experience of the job scheduler at scale). They may be at times out of sync
with the latest version of eHive.
They are nevertheless usually continuously tested on `Travis CI
<https://travis-ci.org/Ensembl>`__ using single-machine Docker
installations.  You can check the badge on the repositories' home page to
verify they are still compatible.

SGE
  A meadow that supports Sun Grid Engine (now known as Oracle Grid Engine). Available for download on GitHub at `Ensembl/ensembl-hive-sge <https://github.com/Ensembl/ensembl-hive-sge>`__.

HTCondor
  A meadow that supports `HTCondor <https://research.cs.wisc.edu/htcondor/>`__. Available for download on GitHub at `Ensembl/ensembl-hive-htcondor <https://github.com/Ensembl/ensembl-hive-htcondor>`__.

PBSPro
  A meadow that supports `PBS Pro <http://www.pbspro.org>`__. Available for download on GitHub at `Ensembl/ensembl-hive-pbspro <https://github.com/Ensembl/ensembl-hive-pbspro>`__.

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
     - Not implemented
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
   * - DockerSwarm
     - Yes
     - Yes
     - Not implemented
     - Yes
     - Not implemented
