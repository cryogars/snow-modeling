from contextlib import contextmanager

from dask.distributed import Client
from dask_jobqueue import SLURMCluster


def start_cluster(cores=6, memory=None):
    """
    Start up a Dask cluster with requested resources.
    Default is to use a remote sever and use SLURM to request the resources.

    :param cores: Number of needed cores
    :param memory: Total memory across all cores
    :param local: Start a local cluster instead using a remote server
    :return: Dask Client object to interact with the cluster
    """
    cluster = SLURMCluster(
        account='csu-general',
        queue='csu',
        cores=cores,
        processes=cores,
        n_workers=1,
        memory=f"{memory or cores}G",
        walltime="2:00:00",
    )

    return Client(cluster)


def client_ip_and_port(client):
    """
    Print client IP and Port information as string.

    :param client: Instance of dask.distributed.Client
    """
    print(client.dashboard_link.split('/')[2])


def slurm_script(client):
    """
    Print the slurm script that would be submitted to start the cluster

    :param client: Instance of dask.distributed.Client
    :return: str: slurm script
    """
    print(client.jobscript())


@contextmanager
def run_with_client(cores, memory):
    client = start_cluster(cores, memory)
    print(client.dashboard_link)
    try:
        yield client
    finally:
        client.shutdown()
