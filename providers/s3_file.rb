include Opscode::Aws::S3
use_inline_resources if defined?(use_inline_resources)

def whyrun_supported?
  true
end

action :create do
  do_s3_file(:create)
end

action :create_if_missing do
  do_s3_file(:create_if_missing)
end

action :delete do
  do_s3_file(:delete)
end

action :touch do
  do_s3_file(:touch)
end

def do_s3_file(resource_action)
  version = Chef::Version.new(Chef::VERSION[/^(\d+\.\d+\.\d+)/, 1])
  if version.major < 11 || (version.major == 11 && version.minor < 6)
    Chef::Log.warn('In order to automatically use etag support to prevent re-downloading files from s3, you must upgrade to at least chef 11.6.0')
  end

  remote_path = new_resource.remote_path
  remote_path.sub!(/^\/*/, '')

  obj = ::Aws::S3::Object.new(bucket_name: new_resource.bucket, key: remote_path, client: s3)
  s3url = obj.presigned_url(:get, expires_in: 300)

  remote_file new_resource.name do
    path new_resource.path
    source s3url.gsub(/https:\/\/([\w\.\-]*)\.{1}s3.amazonaws.com:443/, 'https://s3.amazonaws.com:443/\1') # Fix for ssl cert issue
    owner new_resource.owner
    group new_resource.group
    mode new_resource.mode
    checksum new_resource.checksum
    backup new_resource.backup
    if node['platform_family'] == 'windows'
      inherits new_resource.inherits
      rights new_resource.rights
    end
    action resource_action

    if version.major > 11 || (version.major == 11 && version.minor >= 6)
      headers new_resource.headers
      use_etag new_resource.use_etag
      use_last_modified new_resource.use_last_modified
      atomic_update new_resource.atomic_update
      force_unlink new_resource.force_unlink
      manage_symlink_source new_resource.manage_symlink_source
    end
  end
end
