# Coverity VSTS Build Task

Please note that this is very much a work-in-progress and it is only built to facilitate the needs I/We have at work (http://www.infosoft.no).
Feel free to make comments, suggestion, PRs etc, but don't expect too much in the way of "bug fixing" if you discover a bug.


# Installing the Coverity Build Task
* Install Node.js
* Install the tfx-cli using `npm install -g tfx-cli`
* Clone the repository `git clone https://github.com/esbenbach/coverity-vsts-task.git`
* Login to vsts with tfx `tfx login -u https://youraccount.visualstudio.com/DefaultCollection -t "PERSONALACCESSTOKEN"` - its possible to use username or password instead of the access token read the `tfx --help` to figure out how
* Upload the task to vsts `tfx build tasks upload --task-path ./coverity-vsts-task/CoverityBuild`

# Using the Coverity Build Task
* Edit a build definition and add the task "Coverity Build"
* Fill out all the required parameters, note that aside from the solution path, all paths relates to the agent where the build is executed, so if you have multiple agents you probably need to either install coverity in a specific location or enforce the build to run on a specific agent.

# Regarding MSBuild
Since this is my very first attempt to do a vsts task, i took the quick way around and just used a third party script to find msbuild, and I choose to just use the arguments for MSBuild that I need.
It should be relatively easy to augment it if you want, but ideally it should somehow wrap the VSBuild task if that is possible (not sure it is). I might look into that in the future.
