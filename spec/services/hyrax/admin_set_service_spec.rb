RSpec.describe Hyrax::AdminSetService do
  let(:controller) { ::CatalogController.new }
  let(:context) do
    double(current_ability: Ability.new(user),
           repository: controller.repository,
           blacklight_config: controller.blacklight_config)
  end
  let(:service) { described_class.new(context) }
  let(:user) { create(:user) }

  describe "#search_results", :clean_repo do
    subject { service.search_results(access) }

    let!(:as1) { create(:admin_set, read_groups: ['public'], title: ['foo']) }
    let!(:as2) { create(:admin_set, read_groups: ['public'], title: ['bar']) }
    let!(:as3) { create(:admin_set, edit_users: [user.user_key], title: ['baz']) }

    before do
      create(:collection, :public) # this should never be returned.
    end

    context "with read access" do
      let(:access) { :read }

      it "returns three admin sets" do
        expect(subject.map(&:id)).to match_array [as1.id, as2.id, as3.id]
      end
    end

    context "with edit access" do
      let(:access) { :edit }

      it "returns one admin set" do
        expect(subject.map(&:id)).to match_array [as3.id]
      end
    end
  end

  context "with injection" do
    subject { service.search_results(access) }

    let(:service) { described_class.new(context, search_builder) }
    let(:access) { :edit }
    let(:search_builder) { double(new: search_builder_instance) }
    let(:search_builder_instance) { double }

    it "calls the injected search builder" do
      expect(search_builder_instance).to receive(:rows).and_return(search_builder_instance)
      expect(search_builder_instance).to receive(:reverse_merge).and_return({})
      subject
    end
  end

  describe '#search_results_with_work_count' do
    subject { service.search_results_with_work_count(access) }

    let(:access) { :read }
    let(:documents) { [doc1, doc2, doc3] }
    let(:doc1) { SolrDocument.new(id: 'xyz123') }
    let(:doc2) { SolrDocument.new(id: 'yyx123') }
    let(:doc3) { SolrDocument.new(id: 'zxy123') }
    let(:connection) { instance_double(RSolr::Client) }
    let(:facets) { { 'isPartOf_ssim' => [doc1.id, 8, doc2.id, 2] } }

    let(:results) do
      {
        'response' =>
          {
            'docs' => []
          },
        'facet_counts' =>
          {
            'facet_fields' => facets
          }
      }
    end

    let(:xyz123_file_results) do
      {
        'response' =>
          {
            'numFound' => xyz123_files
          }
      }
    end

    let(:yyx123_file_results) do
      {
        'response' =>
          {
            'numFound' => yyx123_files
          }
      }
    end

    let(:zxy123_file_results) do
      {
        'response' =>
          {
            'numFound' => zxy123_files
          }
      }
    end

    let(:struct) { described_class::SearchResultForWorkCount }

    before do
      allow(service).to receive(:search_results).and_return(documents)
      allow(ActiveFedora::SolrService.instance).to receive(:conn).and_return(connection)
      allow(connection).to receive(:get).with("select", params: { fq: "{!terms f=isPartOf_ssim}xyz123,yyx123,zxy123",
                                                                  "facet.field" => "isPartOf_ssim", rows: 0 }).and_return(results)
      allow(connection).to receive(:get).with("select", params: { fq: ["{!join from=file_set_ids_ssim to=id}isPartOf_ssim:xyz123", "has_model_ssim:FileSet"], rows: 0 }).and_return(xyz123_file_results)
      allow(connection).to receive(:get).with("select", params: { fq: ["{!join from=file_set_ids_ssim to=id}isPartOf_ssim:yyx123", "has_model_ssim:FileSet"], rows: 0 }).and_return(yyx123_file_results)
      allow(connection).to receive(:get).with("select", params: { fq: ["{!join from=file_set_ids_ssim to=id}isPartOf_ssim:zxy123", "has_model_ssim:FileSet"], rows: 0 }).and_return(zxy123_file_results)
    end

    context "when there are works in the admin set" do
      let(:xyz123_files) { '3' }
      let(:yyx123_files) { '2' }
      let(:zxy123_files) { '0' }

      it "returns rows with document in the first column and integer count value in the second and third column" do
        expect(subject).to eq [struct.new(doc1, 8, 3), struct.new(doc2, 2, 2), struct.new(doc3, 0, 0)]
      end
    end

    context "when there are no files in the admin set" do
      let(:xyz123_files) { '0' }
      let(:yyx123_files) { '0' }
      let(:zxy123_files) { '0' }

      it "returns rows with document in the first column and integer count value in the second and third column" do
        expect(subject).to eq [struct.new(doc1, 8, 0), struct.new(doc2, 2, 0), struct.new(doc3, 0, 0)]
      end
    end
  end
end
