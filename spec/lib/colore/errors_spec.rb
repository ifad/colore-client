# frozen_string_literal: true

require 'spec_helper'

describe Colore::Errors do
  let(:bad_request) do
    { 'status' => 400, 'description' => 'foo', 'backtrace' => 'a backtrace' }
  end
  let(:internal_server_error) do
    { 'status' => 500, 'description' => 'foo', 'backtrace' => 'a backtrace' }
  end

  describe '.from' do
    it 'handles nil hash' do
      expect(described_class.from(nil, 'foo')).to be_a described_class::ServerError
    end

    it 'handles 400 error' do
      expect(described_class.from(bad_request, 'foo')).to be_a described_class::ClientError
    end

    it 'handles 500 error' do
      expect(described_class.from(internal_server_error, 'foo')).to be_a described_class::ServerError
    end
  end
end
