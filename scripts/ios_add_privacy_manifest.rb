# Adds ios/Runner/PrivacyInfo.xcprivacy to the Runner target's
# "Copy Bundle Resources" phase of the Xcode project that CI generates with
# `flutter create`. Idempotent. Uses the xcodeproj gem shipped with CocoaPods.
#
#   ruby scripts/ios_add_privacy_manifest.rb [path/to/Runner.xcodeproj]
require "xcodeproj"

project_path = ARGV[0] || "ios/Runner.xcodeproj"
manifest_path = File.join(File.dirname(project_path), "Runner", "PrivacyInfo.xcprivacy")
abort("Privacy manifest not found: #{manifest_path}") unless File.file?(manifest_path)

project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == "Runner" } or abort("Runner target not found")
group = project.main_group.find_subpath("Runner", false) or abort("Runner group not found")

file_ref = group.files.find { |f| f.path == "PrivacyInfo.xcprivacy" }
file_ref ||= group.new_reference("PrivacyInfo.xcprivacy")
file_ref.last_known_file_type = "text.xml"

phase = target.resources_build_phase
if phase.files_references.include?(file_ref)
  puts "PrivacyInfo.xcprivacy already in Runner resources."
else
  phase.add_file_reference(file_ref, true)
  puts "Added PrivacyInfo.xcprivacy to Runner resources."
end
project.save
