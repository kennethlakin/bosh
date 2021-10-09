require_relative '../spec_helper'

describe 'update settings configuration', type: :integration do
  with_reset_sandbox_before_each

  it 'should update the trusted certificates if they were changed' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest_with_instance_groups
    deploy_from_scratch(cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config, manifest_hash: manifest_hash)

    current_sandbox.trusted_certs = 'new trusted certs'
    current_sandbox.director_service.stop
    current_sandbox.director_service.start(current_sandbox.director_config)

    director.start_recording_nats
    deploy_simple_manifest(manifest_hash: manifest_hash)

    nats_messages = extract_agent_messages(director.finish_recording_nats, director.instance('foobar', '0').agent_id).join(',')
    expect(nats_messages).to match /stop.*update_settings.*start/
  end
end
