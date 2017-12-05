require 'spec_helper'

describe Gitlab::BackgroundMigration::MigrateBuildStage, :migration, schema: 20171205101928 do
  let(:projects) { table(:projects) }
  let(:pipelines) { table(:ci_pipelines) }
  let(:stages) { table(:ci_stages) }
  let(:jobs) { table(:ci_builds) }

  STATUSES = { created: 0, pending: 1, running: 2, success: 3,
               failed: 4, canceled: 5, skipped: 6, manual: 7 }.freeze

  before do
    ##
    # Dependencies
    #
    projects.create!(id: 123, name: 'gitlab', path: 'gitlab-ce')
    pipelines.create!(id: 1, project_id: 123, ref: 'master', sha: 'adf43c3a')

    ##
    # CI/CD jobs
    #
    jobs.create!(id: 1, commit_id: 1, project_id: 123,
                 stage_idx: 2, stage: 'build', status: :success)
    jobs.create!(id: 2, commit_id: 1, project_id: 123,
                 stage_idx: 2, stage: 'build', status: :success)
    jobs.create!(id: 3, commit_id: 1, project_id: 123,
                 stage_idx: 1, stage: 'test', status: :failed)
    jobs.create!(id: 4, commit_id: 1, project_id: 123,
                 stage_idx: 1, stage: 'test', status: :success)
    jobs.create!(id: 5, commit_id: 1, project_id: 123,
                 stage_idx: 3, stage: 'deploy', status: :pending)
  end

  it 'correctly migrates builds stages' do
    expect(stages.count).to be_zero

    jobs.all.find_each do |job|
      described_class.new.perform(job.id)
    end

    expect(stages.count).to eq 3
    expect(stages.all.pluck(:name)).to match_array %w[test build deploy]
    expect(jobs.where(stage_id: nil)).to be_empty
    expect(stages.all.pluck(:status)).to match_array [STATUSES[:success],
                                                      STATUSES[:failed],
                                                      STATUSES[:pending]]
  end
end
