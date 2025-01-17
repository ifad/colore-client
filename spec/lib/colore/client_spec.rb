# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Colore::Client, :vcr do
  let(:client) { described_class.new app: 'client_test', base_uri: 'http://localhost:9240/' }
  let(:filename) { fixture('quickfox.jpg') }

  describe '.generate_doc_id' do
    it 'runs' do
      expect(described_class.generate_doc_id.to_s).not_to eq ''
    end
  end

  describe '#generate_doc_id' do
    it 'runs' do
      expect(client.generate_doc_id.to_s).not_to eq ''
    end
  end

  describe '#ping' do
    it 'runs' do
      expect(client.ping).to be true
    end

    it 'raises error on failure' do
      client2 = described_class.new app: 'client_test', base_uri: 'foo'
      expect { client2.ping }.to raise_error URI::BadURIError
    end

    it 'raises ColoreUnavailable on ECONNREFUSED' do
      allow(client.send(:connection)).to receive(:get) { raise Faraday::ConnectionFailed }
      expect { client.ping }.to raise_error(Colore::Errors::ColoreUnavailable)
    end
  end

  describe '#create_document' do
    it 'runs' do
      doc_id = 'test_doc_1'
      rsp = client.create_document(
        doc_id: doc_id,
        filename: filename,
        content: File.read(filename),
        title: 'Sample document',
        author: 'spliffy',
        actions: ['ocr'],
        callback_url: nil
      )
      expect(rsp).not_to be_nil
      expect(rsp['status']).to eq 201
      expect(rsp['description'].to_s).not_to eq ''
      expect(rsp['path'].to_s).not_to eq ''
    end

    it 'fails if document exists' do
      doc_id = 'test_doc_2'
      client.create_document(
        doc_id: doc_id,
        filename: filename,
        content: File.read(filename),
        title: 'Sample document',
        author: 'spliffy',
        actions: ['ocr'],
        callback_url: nil
      )
      expect do
        client.create_document(
          doc_id: doc_id,
          filename: filename,
          content: File.read(filename),
          title: 'Sample document',
          actions: ['ocr'],
          callback_url: nil
        )
      end.to raise_error Colore::Errors::ClientError, 'A document with this doc_id already exists'
    end
  end

  describe '#update_document' do
    it 'runs' do
      doc_id = 'test_update_1'
      client.create_document(
        doc_id: doc_id,
        filename: filename,
        author: 'spliffy',
        content: File.read(filename)
      )
      rsp = client.update_document(
        doc_id: doc_id,
        filename: filename,
        author: 'spliffy',
        content: File.read(filename)
      )
      expect(rsp['status']).to eq 201
      expect(rsp['description'].to_s).not_to eq ''
      expect(rsp['path'].to_s).not_to eq ''
    end

    it 'fails on an invalid doc_id' do
      expect do
        client.update_document(
          doc_id: 'foo',
          filename: filename,
          author: 'spliffy',
          content: File.read(filename)
        )
      end.to raise_error Colore::Errors::ClientError, 'Document not found'
    end
  end

  describe '#update_title' do
    it 'runs' do
      doc_id = 'test_update_title_1'
      client.create_document(
        doc_id: doc_id,
        filename: filename,
        content: File.read(filename)
      )
      rsp = client.update_title(doc_id: doc_id, title: 'This is a new title')
      expect(rsp['status']).to eq 200
      expect(rsp['description'].to_s).not_to eq ''
    end

    it 'fails on an invalid doc_id' do
      expect do
        client.update_title(doc_id: 'foo', title: 'foo')
      end.to raise_error Colore::Errors::ClientError, 'Document not found'
    end
  end

  describe '#request_conversion' do
    it 'runs' do
      doc_id = 'test_new_conv_1'
      client.create_document(
        doc_id: doc_id,
        filename: filename,
        content: File.read(filename),
        title: 'Sample document'
      )
      rsp = client.request_conversion(
        doc_id: doc_id,
        version: Colore::CURRENT,
        filename: filename,
        action: 'ocr'
      )
      expect(rsp['status']).to eq 202
      expect(rsp['description'].to_s).not_to eq ''
    end
  end

  describe '#delete_document' do
    it 'runs' do
      doc_id = 'test_delete_doc_1'
      client.create_document(
        doc_id: doc_id,
        filename: filename,
        content: File.read(filename),
        title: 'Sample document'
      )
      rsp = client.delete_document(doc_id: doc_id)
      expect(rsp['status']).to eq 200
      expect(rsp['description'].to_s).not_to eq ''
    end
  end

  describe '#delete_version' do
    it 'runs' do
      doc_id = 'test_delete_version_1'
      client.create_document(
        doc_id: doc_id,
        filename: filename,
        content: File.read(filename),
        title: 'Sample document'
      )
      client.update_document(
        doc_id: doc_id,
        filename: filename,
        content: File.read(filename)
      )
      rsp = client.delete_version(doc_id: doc_id, version: 'v001')
      expect(rsp['status']).to eq 200
      expect(rsp['description'].to_s).not_to eq ''
    end

    it 'refuses to delete the current version' do
      doc_id = 'test_delete_version_2'
      client.create_document(
        doc_id: doc_id,
        filename: filename,
        content: File.read(filename),
        title: 'Sample document'
      )
      client.update_document(
        doc_id: doc_id,
        filename: filename,
        content: File.read(filename)
      )
      expect do
        client.delete_version(doc_id: doc_id, version: 'v002')
      end.to raise_error Colore::Errors::ClientError, 'Version is current, change current version first'
    end
  end

  describe '#get_document' do
    it 'runs' do
      doc_id = 'test_get_doc_1'
      client.create_document(
        doc_id: doc_id,
        filename: filename,
        content: File.read(filename),
        title: 'Sample document'
      )
      rsp = client.get_document doc_id: doc_id, version: Colore::CURRENT, filename: filename
      expect(rsp).to be_a String
      expect(rsp).not_to eq ''
      expect(rsp.mime_type).to eq 'image/jpeg; charset=binary'
    end

    it 'raises error if the file does not exist' do
      expect do
        client.get_document doc_id: 'foo', version: Colore::CURRENT, filename: filename
      end.to raise_error Colore::Errors::ClientError, 'Document not found'
    end
  end

  describe '#get_document_info' do
    it 'runs' do
      doc_id = 'test_get_docinfo_1'
      client.create_document(
        doc_id: doc_id,
        filename: filename,
        content: File.read(filename),
        title: 'Sample document'
      )
      rsp = client.get_document_info doc_id: doc_id
      expect(rsp['status']).to eq 200
      expect(rsp['description'].to_s).not_to eq ''
      expect(rsp['current_version']).to eq 'v001'
      expect(rsp['versions']).not_to be_nil
      expect(rsp['title']).to eq 'Sample document'
    end

    it 'raises error if the file does not exist' do
      expect do
        client.get_document_info doc_id: 'foo'
      end.to raise_error Colore::Errors::ClientError, 'Document not found'
    end
  end

  describe '#convert' do
    it 'runs' do
      rsp = client.convert content: File.read(filename), action: 'ocr_text'
      expect(rsp).to be_a String
      expect(rsp).not_to eq ''
      expect(rsp.mime_type).to eq 'text/plain; charset=us-ascii'
    end

    it 'fails on invalid action' do
      expect do
        client.convert content: File.read(filename), action: 'foobar'
      end.to raise_error Colore::Errors::ClientError, "No task found for action: 'foobar', mime_type: 'image/jpeg; charset=binary'"
    end
  end

  describe '#path_for' do
    let(:doc_id) { 'test_doc_1' }

    it 'returns the document path' do
      url = client.path_for(
        doc_id,
        filename
      )
      expect(url).to eq '/document/client_test/test_doc_1/current/quickfox.jpg'
    end

    it 'returns the document path for a version' do
      url = client.path_for(
        doc_id,
        filename,
        'v001'
      )
      expect(url).to eq '/document/client_test/test_doc_1/v001/quickfox.jpg'
    end
  end
end
