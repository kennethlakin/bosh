require 'spec_helper'

module Bosh::Director
  describe Errand::InstanceMatcher do
    subject(:matcher) { Errand::InstanceMatcher.new(requested) }
    let(:instances_in_group) { [] }

    describe '#match' do
      let(:instance) { instance_double(DeploymentPlan::Instance, job_name: 'group-name') }
      let(:instance_group) { instance_double(DeploymentPlan::InstanceGroup, instances: [instance], name: 'group-name') }

      context 'when no requested instances are supplied' do
        let(:requested) { [] }

        it 'matches always' do
          matching_instances, unmatched = matcher.match([instance_group])
          expect( matching_instances ).to eq({instance_group => [instance]})
          expect( unmatched ).to eq []
        end
      end

      context 'when matching by group name' do
        let(:instance2) { instance_double(DeploymentPlan::Instance, job_name: 'group-name-2') }
        let(:instance_group2) { instance_double(DeploymentPlan::InstanceGroup, instances: [instance2], name: 'group-name-2') }

        let(:requested) { [{'group' => 'group-name'}] }

        it 'returns all instances from the group but no other' do
          matching_instances, unmatched = matcher.match([instance_group, instance_group2])
          expect( matching_instances ).to eq(instance_group => [instance])
          expect( unmatched ).to eq []
        end

        context 'when the group name does not exist' do
          let(:requested) { [{'group' => 'does-not-exist'}] }

          it 'reports unmatched filter' do
            matching_instances, unmatched = matcher.match([instance_group, instance_group2])
            expect( matching_instances.empty? ).to be_truthy
            expect( unmatched ).to contain_exactly(*requested)
          end
        end

        context 'when the group specified is real but with 0 instances' do
          let(:instance_group) { instance_double(DeploymentPlan::InstanceGroup, instances: [], name: 'group-name') }

          it 'reports no instances and no unmatched' do
            matching_instances, unmatched = matcher.match([instance_group, instance_group2])
            expect( matching_instances.empty? ).to be_truthy
            expect( unmatched ).to eq []
          end
        end
        context 'when matching by group name and uuid' do
          let(:requested) { [{'group' => 'group-name', 'id' => '123abc'}] }
          let(:instance) { instance_double(DeploymentPlan::Instance, job_name: 'group-name', uuid: '123abc', index: 2) }
          let(:instance_group) { instance_double(DeploymentPlan::InstanceGroup, instances: [instance], name: 'group-name') }

          context 'when the instance does not match' do
            let(:requested) { [{'group' => 'group-name', 'id' => '123def'}] }

            it 'reports unmatched filter' do
              matching_instances, unmatched = matcher.match([instance_group])
              expect( matching_instances.empty? ).to be_truthy
              expect( unmatched ).to eq [*requested]
            end
          end

          context 'when the instance matches' do
            let(:requested) { [{'group' => 'group-name', 'id' => '123abc'}] }

            it 'returns true' do
              matching_instances, unmatched = matcher.match([instance_group])
              expect( matching_instances ).to eq instance_group => [instance]
              expect( unmatched ).to eq []
            end

          end
        end
        context 'when matching by group name and index' do
          let(:instance) { instance_double(DeploymentPlan::Instance, job_name: 'group-name', uuid: '123abc', index: 2) }
          let(:instance_group) { instance_double(DeploymentPlan::InstanceGroup, instances: [instance], name: 'group-name') }

          context 'when the instance matches' do
            let(:requested) { [{'group' => 'group-name', 'id' => '2'}] }
            it 'returns true' do
              matching_instances, unmatched = matcher.match([instance_group])
              expect( matching_instances ).to eq instance_group => [instance]
              expect( unmatched ).to eq []
            end
          end

          context 'when the instance does not match' do
            let(:requested) { [{'group' => 'group-name', 'id' => '3'}] }


            it 'reports unmatched requests' do
              matching_instances, unmatched = matcher.match([instance_group, instance_group2])
              expect( matching_instances.empty? ).to be_truthy
              expect( unmatched ).to contain_exactly(*requested)
            end
          end
        end
        context 'when criteria overlap' do
          let(:instance) { instance_double(DeploymentPlan::Instance, job_name: 'group-name', uuid: '123abc', index: 2) }
          let(:instance_group) { instance_double(DeploymentPlan::InstanceGroup, instances: [instance], name: 'group-name') }

          context 'when the instance matches all crieterias' do
            let(:requested) { [{'group' => 'group-name', 'id' => '2'}, {'group' => 'group-name', 'id' => '123abc'}, {'group' => 'group-name'}] }

            it 'reports no unmatched requests' do
              matching_instances, unmatched = matcher.match([instance_group])
              expect( matching_instances ).to eq instance_group => [instance]
              expect( unmatched ).to eq []
            end
          end

          context 'when the instance matches some criteria' do
            let(:requested) { [{'group' => 'group-name', 'id' => '2'}, {'group' => 'group-name', 'id' => '123abc'}, {'group' => 'other-group-name'}] }

            it 'reports unmatched requests' do
              matching_instances, unmatched = matcher.match([instance_group, instance_group2])
              expect( matching_instances ).to eq instance_group => [instance]
              expect( unmatched ).to contain_exactly({'group' => 'other-group-name'})
            end
          end
        end
        context 'when run against multiple instances' do
          let(:instance1) { instance_double(DeploymentPlan::Instance, job_name: 'group-name', uuid: '123abc', index: 2) }
          let(:instance2) { instance_double(DeploymentPlan::Instance, job_name: 'group-name', uuid: '123def', index: 0) }
          let(:instance_group) { instance_double(DeploymentPlan::InstanceGroup, instances: [instance1,instance2], name: 'group-name') }

          let(:requested) { [{'group' => 'group-name', 'id' => '2'}, {'group' => 'group-name', 'id' => '123def'}, {'group' => 'other-group-name', 'id' => 'foo'}] }

          it 'recalls all that criteria that have ever been matched by any instance' do
            matching_instances, unmatched = matcher.match([instance_group])
            expect( matching_instances ).to eq instance_group => [instance1, instance2]
            expect( unmatched ).to contain_exactly({'group' => 'other-group-name', 'id' => 'foo'})
          end
        end
        context 'when matching by instance-group/first' do
          let(:instance1) { instance_double(DeploymentPlan::Instance, job_name: 'group-name', uuid: 'a', index: 2) }
          let(:instance2) { instance_double(DeploymentPlan::Instance, job_name: 'group-name', uuid: 'b', index: 0) }
          let(:instance3) { instance_double(DeploymentPlan::Instance, job_name: 'group-name', uuid: 'c', index: 0) }
          let(:instance_group) { instance_double(DeploymentPlan::InstanceGroup, instances: [instance1,instance2,instance3], name: 'group-name') }

          let(:requested) { [{'group' => 'group-name', 'id' => 'first'}] }

          it 'matches on the instance with the first instance sorted by uuid' do
            matching_instances, unmatched = matcher.match([instance_group])
            expect( matching_instances ).to eq instance_group => [instance1]
            expect( unmatched ).to eq []
          end
        end
        context 'with malformed filters' do
          let(:instance) { instance_double(DeploymentPlan::Instance, job_name: 'group-name') }
          let(:instance_group) { instance_double(DeploymentPlan::InstanceGroup, instances: [instance], name: 'group-name') }
          let(:requested) { ['group', 7, [], nil] }

          it 'quietly does not match any instances' do
            matching_instances, unmatched = matcher.match([instance_group])
            expect( matching_instances.empty? ).to be_truthy
            expect( unmatched ).to eq [*requested]
          end
        end
      end
    end
  end
end
