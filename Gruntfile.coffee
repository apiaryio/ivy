module.exports = (grunt) ->
  grunt.loadNpmTasks 'grunt-bump'
  grunt.loadNpmTasks 'grunt-exec'

  grunt.initConfig
    exec:
      tests:
        cmd: "npm test"
    bump:
      options:
        files: ["package.json"]
        updateConfigs: []
        commit: true
        commitMessage: "Version bump"
        commitFiles: ["package.json"]
        createTag: true
        tagName: "ivy-%VERSION%"
        push: true
        gitDescribeOptions: "--tags --always --abbrev=1 --dirty=-d"

  grunt.registerTask 'default', ['exec:tests']
