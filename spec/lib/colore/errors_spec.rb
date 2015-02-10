require 'spec_helper'

describe Colore::Errors do
  let(:hash_400) {
      { 'status'=>400, 'description'=>'foo', 'backtrace'=>'a backtrace' }
    }
  let(:hash_500) {
      { 'status'=>500, 'description'=>'foo', 'backtrace'=>'a backtrace' }
    }
  context '.from' do
    it 'handles nil hash' do
      expect(described_class.from nil, 'foo').to be_a described_class::ServerError
    end

    it 'handles 400 error' do
      expect(described_class.from hash_400, 'foo').to be_a described_class::ClientError
    end

    it 'handle 500 error' do
      expect(described_class.from hash_500, 'foo').to be_a described_class::ServerError
    end
  end
end
