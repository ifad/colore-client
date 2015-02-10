require 'spec_helper'

describe Colore::Client, :vcr do
  let(:client) { described_class.new app: 'client_test' }
  let(:filename) { fixture('quickfox.jpg') }

  context '.generate_doc_id' do
    it 'runs' do
      expect(described_class.generate_doc_id.to_s).to_not eq ''
    end
  end

  context '#generate_doc_id' do
    it 'runs' do
      expect(client.generate_doc_id.to_s).to_not eq ''
    end
  end

  context '#ping' do
    it 'runs' do
      expect(client.ping).to eq true
    end

    it 'raises error on failure' do
      client2 = described_class.new app: 'client_test', base_uri: 'foo'
      expect{client2.ping}.to raise_error
    end
  end

  context '#create_document' do
    it 'runs' do
      doc_id = 'test_doc_1'
      rsp = client.create_document(
        doc_id: doc_id,
        filename: filename,
        content: File.read(filename),
        title: 'Sample document',
        actions: [ 'ocr' ],
        callback_url: nil )
      expect(rsp).to_not be_nil
      expect(rsp.status).to eq 201
      expect(rsp.description.to_s).to_not eq ''
      expect(rsp.path.to_s).to_not eq ''
    end

    it 'fails if document exists' do
      doc_id = 'test_doc_2'
      client.create_document(
        doc_id: doc_id,
        filename: filename,
        content: File.read(filename),
        title: 'Sample document',
        actions: [ 'ocr' ],
        callback_url: nil )
      expect {
        client.create_document(
          doc_id: doc_id_2,
          filename: filename,
          content: File.read(filename),
          title: 'Sample document',
          actions: [ 'ocr' ],
          callback_url: nil )
      }.to raise_error
    end
  end

  context '#update_document' do
    it 'runs' do
      doc_id = 'test_update_1'
      client.create_document(
        doc_id: doc_id,
        filename: filename,
        content: File.read(filename) )
      rsp = client.update_document(
        doc_id: doc_id,
        filename: filename,
        content: File.read(filename)
      )
      expect(rsp.status).to eq 201
      expect(rsp.description.to_s).to_not eq ''
      expect(rsp.path.to_s).to_not eq ''
    end

    it 'fails on an invalid doc_id' do
      expect{
        client.update_document(
          doc_id: 'foo',
          filename: filename,
          content: File.read(filename)
        ) }.to raise_error
    end
  end

  context '#update_title' do
    it 'runs' do
      doc_id = 'test_update_title_1'
      client.create_document(
        doc_id: doc_id,
        filename: filename,
        content: File.read(filename) )
      rsp = client.update_title( doc_id: doc_id, title: 'This is a new title' )
      expect(rsp.status).to eq 200
      expect(rsp.description.to_s).to_not eq ''
    end

    it 'fails on an invalid doc_id' do
      expect{
        client.update_document( doc_id: 'foo', title: 'foo' )
      }.to raise_error
    end
  end

  context '#request_conversion' do
    it 'runs' do
      doc_id = 'test_new_conv_1'
      client.create_document(
        doc_id: doc_id,
        filename: filename,
        content: File.read(filename),
        title: 'Sample document' )
      rsp = client.request_conversion(
        doc_id: doc_id,
        version: Colore::CURRENT,
        filename: filename,
        action: 'ocr'
      )
      expect(rsp.status).to eq 202
      expect(rsp.description.to_s).to_not eq ''
    end
  end

  context '#delete_document' do
    it 'runs' do
      doc_id = 'test_delete_doc_1'
      client.create_document(
        doc_id: doc_id,
        filename: filename,
        content: File.read(filename),
        title: 'Sample document' )
      rsp = client.delete_document( doc_id: doc_id)
      expect(rsp.status).to eq 200
      expect(rsp.description.to_s).to_not eq ''
    end
  end

  context '#delete_version' do
    it 'runs' do
      doc_id = 'test_delete_version_1'
      client.create_document(
        doc_id: doc_id,
        filename: filename,
        content: File.read(filename),
        title: 'Sample document' )
      client.update_document(
        doc_id: doc_id,
        filename: filename,
        content: File.read(filename)
      )
      rsp = client.delete_version( doc_id: doc_id, version: 'v001')
      expect(rsp.status).to eq 200
      expect(rsp.description.to_s).to_not eq ''
    end

    it 'refuses to delete the current version' do
      doc_id = 'test_delete_version_2'
      client.create_document(
        doc_id: doc_id,
        filename: filename,
        content: File.read(filename),
        title: 'Sample document' )
      client.update_document(
        doc_id: doc_id,
        filename: filename,
        content: File.read(filename)
      )
      expect{
        client.delete_version( doc_id: doc_id, version: 'v002')
      }.to raise_error
    end
  end

  context '#get_document' do
    it 'runs' do
      doc_id = 'test_get_doc_1'
      client.create_document(
        doc_id: doc_id,
        filename: filename,
        content: File.read(filename),
        title: 'Sample document' )
      rsp = client.get_document doc_id: doc_id, version: Colore::CURRENT, filename: filename
      expect(rsp).to be_a String
      expect(rsp).to_not eq ''
      expect(rsp.mime_type).to eq 'image/jpeg; charset=binary'
    end

    it 'raises error if the file does not exist' do
      expect{
        client.get_document doc_id: 'foo', version: Colore::CURRENT, filename: filename
      }.to raise_error
    end
  end

  context '#get_document_info' do
    it 'runs' do
      doc_id = 'test_get_docinfo_1'
      client.create_document(
        doc_id: doc_id,
        filename: filename,
        content: File.read(filename),
        title: 'Sample document' )
      rsp = client.get_document_info doc_id: doc_id
      expect(rsp.status).to eq 200
      expect(rsp.description.to_s).to_not eq ''
      expect(rsp.current_version).to eq 'v001'
      expect(rsp.versions).to_not be_nil
      expect(rsp.title).to eq 'Sample document'
    end

    it 'raises error if the file does not exist' do
      expect{
        client.get_document_info doc_id: 'foo'
      }.to raise_error
    end
  end

  context '#convert' do
    it 'runs' do
      rsp = client.convert content: File.read(filename), action: 'ocr_text'
      expect(rsp).to be_a String
      expect(rsp).to_not eq ''
      expect(rsp.mime_type).to eq 'text/plain; charset=us-ascii'
    end

    it 'fails on invalid action' do
      expect{
        client.convert content: File.read(filename), action: 'foobar'
      }.to raise_error
    end
  end
end
