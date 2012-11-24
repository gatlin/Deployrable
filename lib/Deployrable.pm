package Deployrable;
use Mojo::Base 'Mojolicious';

use Mojo::JSON::XS;
use Data::UUID;
use Mojolicious::Plugin::Database;

use Net::OpenStack::Compute;
use Data::Dump qw(pp);

our $VERSION = '0.1';

sub zip { @_[map $_&1 ? $_>>1 : ($_>>1)+($#_>>1), 1..@_] };

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

    #novacertname: "gatlin"
    #novacertpath: "/Users/gatlinjohnson/gatlin.pem"
    my $compute = Net::OpenStack::Compute->new(
        auth_url => $config->{authurl},
        project_id => $config->{tenant_name},
        user => $config->{novauser},
        password => $config->{novapass}
    );

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

        my $projects = $self->db->selectall_arrayref("
            select * from projects;
            ",{Slice => {}}
        );

        $self->stash(projects => $projects);
        $self->stash(title => "Projects");
        $self->stash(breadcrumbs => []);
        $self->render('projects');
    });

    ###
    # Branches for project
    $r->get('/project/:id' => sub {
        my $self = shift;

        my $id = $self->param('id');
        my $rv = $self->db->selectrow_hashref("
            select * from projects
            where
                id = $id;
        ",{Slice => {}});
        my $project = {
            title => $rv->{title},
            host => $rv->{host},
            port => $rv->{port},
            path => $rv->{path},
            repo => $rv->{repo},
        };

        $project->{port} //= 22;
        $project->{path} //= '';
        my @lsremote =
            `git ls-remote
            ssh://git\@$project->{host}:$project->{port}/$project->{path}/$project->{repo}.git`;

        my $query =
        "ssh://git\@$project->{host}:$project->{port}/$project->{path}/$project->{repo}.git";

        my @names= map {
            chomp;
            s{.*refs/heads/(.*)}{$1} and $_ or ();
            } @lsremote;

        my @branches = ();
        for my $i (0..scalar(@names)) {
            push @branches, { id => $i, name => $names[$i] };
        }

        $self->stash(project => $project);
        $self->stash(branches => \@branches);
        $self->stash(debugbranch => pp(@branches));
        $self->stash(names => pp(@names));
        $self->stash(query => $query);
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

        my $images = $compute->get_images(detail => 1);
        my $flavors = $compute->get_flavors(detail => 1);
        my $instances_ = $compute->get_servers(detail => 1);

        my $pid = $self->param('pid');
        my $bid = $self->param('bid');

        my @instances = map {
            $_->{name} =~ m/^$bid/ and $_ or ();
        } @$instances_;

        my $branch = { name => $bid };
        my $rv = $self->db->selectrow_hashref("
            select * from projects
            where
                id = $pid
            ;
        ",{Slice => {}});
        my $project = {
            title => $rv->{title},
            host => $rv->{host},
            path => $rv->{path},
            repo => $rv->{repo},
            port => $rv->{port},
        };

        $self->stash(images => $images);
        $self->stash(flavors => $flavors);
        $self->stash(instances => \@instances);
        $self->stash(branchId => $bid);
        $self->stash(projectId => $project->{title});
        $self->stash(title => $branch->{name});
        $self->stash(breadcrumbs => [
            {name => "Projects", path => "/projects"},
            {name => $project->{title}, path => "/project/$pid"},
        ]);
        $self->stash(debugproject => pp($project));
        $self->render('branch');
    });

    ###
    # Todo:

    $r->get('/instance/:pid/:bid/:iid/stop' => sub {
        my $self = shift;
        my $pid = $self->param('pid');
        my $bid = $self->param('bid');
        my $iid = $self->param('iid');
        $self->redirect_to("/project/$pid/$bid");
    });

    $r->get('/instance/:pid/:bid/:iid/pause' => sub {
        my $self = shift;
        my $pid = $self->param('pid');
        my $bid = $self->param('bid');
        my $iid = $self->param('iid');
        $self->redirect_to("/project/$pid/$bid");
    });

    $r->get('/instance/:pid/:bid/:iid/restart' => sub {
        my $self = shift;
        my $pid = $self->param('pid');
        my $bid = $self->param('bid');
        my $iid = $self->param('iid');
        $self->redirect_to("/project/$pid/$bid");
    });

    $r->post('/deploy' => sub {
        my $self = shift;
        my $pid = $self->param('projectId');
        my $bid = $self->param('branchId');
        my $img = $self->param('image');
        my $flv = $self->param('flavor');

        $self->redirect_to("/project/$pid/$bid");
    });

    $r->post('/projects/new' => sub {
        my $self = shift;
        my $title = $self->param('title');
        my $host = $self->param('host');
        my $repo = $self->param('repo');
        my $path = $self->param('path') // '';
        my $port = $self->param('port') // 0;

        my $sth = $self->db->prepare("
            insert into projects (
                title,
                host,
                repo,
                path,
                port
            )
            values (
                '$title',
                '$host',
                '$repo',
                '$path',
                $port)
                ;
        ");

        my $ret = $sth->execute;

        $self->redirect_to('/projects');
    });

    $r->post('/projects/:pid/destroy' => sub {
        my $self = shift;
        $self->redirect_to('/projects');
    });
}

1;
