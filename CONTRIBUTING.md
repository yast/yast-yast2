YaST Contribution Guidelines
============================

YaST is an open source project and as such it welcomes all kinds of
contributions. If you decide to contribute, please follow these guidelines to
ensure the process is effective and pleasant both for you and YaST maintainers.

There are two main forms of contribution: reporting bugs and performing code
changes.

Bug Reports
-----------

If you find a problem, please report it either using
[Bugzilla](https://bugzilla.suse.com/enter_bug.cgi?format=guided&product=openSUSE+Factory&component=YaST2)
or [GitHub issues](../../issues). (For Bugzilla, use the [simplified
registration](https://secure-www.novell.com/selfreg/jsp/createSimpleAccount.jsp)
if you don't have an account yet.)

If you find a problem, please report it either using
[Bugzilla](https://bugzilla.suse.com/) or GitHub issues. We can't guarantee
that every bug will be fixed, but we'll try.

When creating a bug report, please follow our [bug reporting
guidelines](http://en.opensuse.org/openSUSE:Report_a_YaST_bug).

Code Changes
------------

We welcome all kinds of code contributions, from simple bug fixes to significant
refactorings and implementation of new features. However, before making any
non-trivial contribution, get in touch with us first — this can prevent wasted
effort on both sides. Also, have a look at our [development
documentation](http://en.opensuse.org/openSUSE:YaST_development).

To send us your code change, use GitHub pull requests. The workflow is as
follows:

  1. Fork the project.

  2. Create a topic branch based on `master`.

  3. Implement your change, including tests (if possible). Make sure you adhere
     to the [Ruby style
     guide](https://github.com/SUSE/style-guides/blob/master/Ruby.md).

  4. Make sure your change didn't break anything by building the RPM package
     (`rake osc:build`). The build process includes running the full testsuite.

  5. Publish the branch and create a pull request.

  6. YaST developers will review your change and possibly point out issues.
     Adapt the code under their guidance until they are all resolved.

  7. Finally, the pull request will get merged or rejected.

See also [GitHub's guide on
contributing](https://help.github.com/articles/fork-a-repo).

If you want to do multiple unrelated changes, use separate branches and pull
requests.

Do not change the `VERSION` and `*.changes` files as this could lead to
conflicts.

### Commits

Each commit in the pull request should do only one thing, which is clearly
described by its commit message. Especially avoid mixing formatting changes and
functional changes into one commit. When writing commit messages, adhere to
[widely used
conventions](http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html).

If your commit is related to a bug in Bugzilla or an issue on GitHub, make sure
you mention it in the commit message for cross-reference. Use format like
bnc#775814 or gh#yast/yast-foo#42. See also [GitHub
autolinking](https://help.github.com/articles/github-flavored-markdown#references)
and [openSUSE abbreviation
reference](http://en.opensuse.org/openSUSE:Packaging_Patches_guidelines#Current_set_of_abbreviations).

Additional Information
----------------------

If you have any question, feel free to ask at the [development mailing
list](http://lists.opensuse.org/yast-devel/) or at the
[#yast](http://webchat.freenode.net/?channels=%23yast) IRC channel on freenode.
We'll do our best to provide a timely and accurate answer.
