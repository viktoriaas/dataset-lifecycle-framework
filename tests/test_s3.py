import pytest
from kubetest import client
import os

@pytest.mark.applymanifests('../examples/minio')
def test_s3_simple_mount(kube: client.TestClient):
    minio_deployment = kube.get_deployments(labels={"app":"minio"})["minio"]
    minio_deployment.wait_until_ready(3*60)
    pass