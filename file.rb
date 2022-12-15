require 'gitlab'

# this sets up our connection to our gitlab instance
client = Gitlab.client(
  endpoint: 'Add the endpoint URL here',
  private_token: 'Add your token here'
)

require 'faker'
# let's add a comment

#generates group names
def gen_groups
  [
    Faker::Company.name,
    Faker::Commerce.brand,
    Faker::Hobby.activity,
    Faker::Job.field,
    Faker::Space.company,
    Faker::Space.constellation
  ].sample.gsub(/[^0-9A-Za-z]/, '')
end

def gen_projects
  [
    'Tanuki Inc.' #we only need 1 project for this study
  ].sample.gsub(/[^0-9A-Za-z]/, '')
end

# generates branch names
def gen_branches
  [
    'master',
    'dev',
    'staging',
    Faker::App.name,
    Faker::Computer.stack,
    Faker::Internet.slug,
    Faker::Internet.domain_word,
    Faker::Marketing.buzzwords,
    Faker::Company.catch_phrase,
    Faker::Space.moon,
    Faker::Space.meteorite
  ].sample.gsub(/[^0-9A-Za-z]/, '-')
end

def gen_people
  [
    Faker::Name.name,
    Faker::Science.scientist
  ].sample
end

# this generates descriptions for commits, files, projects, branches, etc.
def gen_description
  [
    Faker::Hacker.say_something_smart,
    Faker::Company.bs,
    Faker::Quote.yoda,
    Faker::Movies::StarWars.quote
  ].sample
end

def gen_label_names
  [
    Faker::Hacker.adjective,
    Faker::Hacker.abbreviation,
    Faker::Hacker.noun,
    Faker::Hacker.verb,
    Faker::Science.element,
    Faker::Science.science
  ].sample
end

def gen_label_colors
  [
    Faker::Color.hex_color
  ].sample
end

# this populates the files that are committed with some very basic code
def gen_commit_code
  [
    Faker::Source.print_1_to_10(lang: :javascript),
    Faker::Source.print(str: "#{gen_description}", lang: :javascript)
  ].sample
end

def gen_date
  [
    Faker::Date.forward(days: 60)
  ].sample
end


# Global Variables for instance setup

user_count = 5 #number of users to create total
group_count = 1 #number of groups to create total

project_count = 1 #number of projects per group
label_count = 10 #number of labels per project
milestone_count = 3 #number of milestones per project

issue_count = 5 # number of issues per project
branch_count = 5 # number of branches per project

file_count = rand(3..8) #number of files per branch (also creates commits)
comment_count = rand(3..8) #number of comments per commit


#generate people names and group names
people = Array.new(user_count) { gen_people }.uniq
groups = Array.new(group_count) { gen_groups }.uniq

# create users
users = people.map do |user|
  username = user.downcase.gsub(/[^0-9A-Za-z]/, '')
  email = "#{username}@tanuki.inc" #consider replacing with your domain
  password = 'tanuki123!' #consider changing or randomly generating passwords
  puts "User -- Name: #{user}, UserName: #{username}, Email: #{email}"
  client.create_user(email, password, username, { name: user, skip_confirmation: true } )
end

# create groups
groups = groups.map do |group|
  path = group.downcase.gsub(/[^0-9A-Za-z]/, '')
  puts "Group -- #{group}/#{path}"
  client.create_group(group, path)
end


# Set access levels / roles
# No access = (0)
# Minimal access = (5) (Introduced in GitLab 13.5.)
# Guest = (10)
# Reporter = (20)
# Developer = (30)
# Maintainer = (40)
# Owner = (50) - Only valid to set for groups

# group_access = [10, 20, 30, 40, 50]
group_access = [30, 40, 50]
groups.each do |group|
  # users.sample(rand(1..users.count)).each do |user|
  users.sample(users.count).each do |user|
    begin
      puts "Group Add: #{group.name}: #{user.name}"
      client.add_group_member(group.id, user.id, group_access.sample)
    rescue StandardError
      next
    end
  end
end


# Create projects
project_names = Array.new
groups.each do |group|
  project_names = Array.new(project_count) { gen_projects }
  project_names.uniq.each do |project|
    puts "Project: #{project}"
    options = {
      description: gen_description,
      default_branch: 'main',
      issues_enabled: 1,
      wiki_enabled: 1,
      merge_requests_enabled: 1,
      snippets_enabled: 1,
      namespace_id: "#{group.id}"

    }
    client.create_project(project, options)
  end
end

projects = Array.new(client.projects.auto_paginate)
proj_id = projects.first.id
puts "#{proj_id}"

project = projects.first
puts "new project being populated: #{project}"

group = client.group(project.to_h.dig('namespace', 'id'))
members = client.group_members(group.id).auto_paginate

#Create Labels
label_count.times do
  label_options = {
    description: gen_description,
    priority: rand(0..10)
  }
  client.create_label(project.id, gen_label_names, Faker::Color.hex_color, label_options)
  puts "label created"
end

labels = client.labels(project.id).auto_paginate
puts "#{labels.sample.name}"

#Create Milestones
milestone_count.times do
  milestone_options = {
    description: gen_description
    #due_date: gen_date
  }
  milestone_title = rand(1.0..19.0).round(1)
  client.create_milestone(project.id, milestone_title.to_s, milestone_options)
  puts "Milestone Created"
end

milestones = client.milestones(project.id).auto_paginate

#Create Issues
issue_count.times do
  options = {
    description: gen_description,
    assignee_id: members.sample.id,
    milestone_id: milestones.sample.id,
    labels: labels.sample.name
  }
  client.create_issue(project.id, Faker::Company.catch_phrase, options)
  puts 'Issue Created'
end

puts "group: #{group.name}"

#Create Branches
branch_names = Array.new(branch_count) { gen_branches }.uniq

branch_names.uniq.each do |branch|
  puts "Branch: #{branch}"
  client.create_branch(project.id, branch, 'main')



  #Create file (also creates a commit)
  file_count.times do
    #create files / commits
    author = members.sample.name
    email = author.delete(' ') + "@tanuki.inc"
    puts "#{email}"
    commit_options = {
      author_name: author,
      author_email: email
    }
    file =  "#{Faker::File.file_name(dir: '', name: "#{gen_label_names}", ext: 'js', directory_separator: '')}"
    client.create_file(project.id, file, branch, gen_commit_code, gen_description, commit_options)
    puts "File Created"
  end

  #Add Comments to commit
  comment_count.times do
    client.create_commit_comment(project.id, branch, gen_description, {})
    puts "Comment Created"
  end

  #Create Merge Request (limit 1 per branch)
  merge_options = {
    source_branch: branch,
    target_branch: 'main',
    assignee_id: members.sample.id,
    description: gen_description,
    labels: labels.sample.name,
    milestone_id: milestones.sample.id,
    remove_source_branch: "#{rand(0..1)}",
    allow_collaboration: "#{rand(0..1)}",
    squash: "#{rand(0..1)}"
  }
  client.create_merge_request(project.id, Faker::Hacker.say_something_smart, merge_options)
  puts 'MR created'

end #end branch iterator
