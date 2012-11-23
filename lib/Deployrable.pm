package Deployrable;
use Mojo::Base 'Mojolicious';

use Mojo::JSON::XS;
use Data::UUID;
use Mojolicious::Plugin::Database;

our $VERSION = '0.1';

sub startup {
    my $self = shift;

    my $config = $self->plugin('yaml_config', {file => 'app.conf'});
    $self->plugin('database', {
            dsn => "DBI:mysql:database=$config->{dbname};
                    host=$config->{dbhost};port=$config->{port}",
                    username => $config->{dbuser},
                    password => $config->{dbpass},
                    options => { AutoCommit => 1 },
                    helper => 'db',
    });

    # Documentation browser under "/perldoc"
    $self->plugin('PODRenderer');

    # Router
    my $r = $self->routes;

    ###
    # default
    $r->get('/' => sub {
        my $self = shift;
        $self->redirect_to('/projects');
    });

    ###
    # Projects
    $r->get('/projects' => sub {
        my $self = shift;

        my $projects = [
            {id => 0, title => "Project 0"},
        ];

        $self->stash(projects => $projects);
        $self->stash(title => "Projects");
        $self->stash(breadcrumbs => []);
        $self->render('projects');
    });

    ###
    # Branches for project
    $r->get('/project/:id' => sub {
        my $self = shift;

        my $branches = [
            {id => 0, name => "hotfix-issue5"},
            {id => 1, name => "menubar-fix"},
            {id => 2, name => "test"},
        ];

        my $project = {
            id => 0,
            title => "Project 0",
        };

        $self->stash(project => $project);
        $self->stash(branches => $branches);
        $self->stash(title => "$project->{title}");
        $self->stash(breadcrumbs => [
            {name => "Projects", path => "/projects"},
        ]);
        $self->render('project_branches');
    });

    ###
    # New
    $r->get('/projects/new' => sub {
        my $self = shift;

        $self->stash(title => "New Project");
        $self->stash(breadcrumbs => [
            {name => "Projects", path => "/projects"},
        ]);
        $self->render('project_new');
    });

    ###
    # Branch
    $r->get('/project/:pid/:bid' => sub {
        my $self = shift;

        my $images = [
            {id => 0, name => "image0"},
            {id => 1, name => "image1"},
            {id => 2, name => "image2"},
        ];

        my $flavors = [
            {id => 0, name => "flavor0"},
            {id => 1, name => "flavor1"},
            {id => 2, name => "flavor2"},
        ];

        my $instances = [
            {id => 0, name => "Instance 1", key_name => "gatlin"},
            {id => 1, name => "Instance 2", key_name => "marin"},
        ];

        my $bid = 0;
        my $pid = 0;

        my $branch = {
            name => "hotfix-issue5",
        };

        my $project = {
            title => "Project 0",
        };

        $self->stash(images => $images);
        $self->stash(flavors => $flavors);
        $self->stash(instances => $instances);
        $self->stash(branchId => $bid);
        $self->stash(projectId => $pid);
        $self->stash(title => $branch->{name});
        $self->stash(breadcrumbs => [
            {name => "Projects", path => "/projects"},
            {name => $project->{title}, path => "/project/$pid"},
        ]);
        $self->render('branch');
    });
}

1;
