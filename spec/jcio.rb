# frozen_string_literal: true

require 'spec_helper'

if Config.jcio_enabled
  describe 'jcio app', :jcio => true do
    before(:all) do
      @kubectl = KUBECTL.new()
    end

    context 'when enabled' do
      it "exists" do
        wait_until(60,10) {
          deployments = @kubectl.get_deployments('jcio')
          expect(deployments).to_not be_nil

          deployments.map! { |deployment| deployment['metadata']['name'] }
          expect(deployments).to include('jcio-frontend', 'moviedb-frontend', 'moviedb-backend')
        }
      end

      it "has running pods for frontend" do
        @kubectl.wait_for_deployment('jcio-frontend', '120s', 'jcio')

        wait_until(120,15) {
          pods = @kubectl.get_pods_by_label("app=jcio,app.kubernetes.io/component=jcio-frontend", 'jcio')
          expect(pods).to_not be_nil
          expect(pods.count).to be == 1 # the deployment has 1 replicas defined

          pods.each{ |pod|
            expect(pod['metadata']['name']).to match(/jcio-frontend-[-a-z0-9]+/)
            expect(pod['status']['phase']).to eq('Running')
            expect(pod['status']['containerStatuses'].count).to be >= 1
            pod['status']['containerStatuses'].each{ |container|
              expect(container['started']).to eq(true)
            }
          }
        }
      end

      it "has running pods for moviedb" do
        @kubectl.wait_for_deployment('moviedb-frontend', '120s', 'jcio')
        @kubectl.wait_for_deployment('moviedb-backend', '120s', 'jcio')

        wait_until(120,15) {
          pods = @kubectl.get_pods_by_label("app=jcio,app.kubernetes.io/component=moviedb-frontend", 'jcio')
          expect(pods).to_not be_nil
          expect(pods.count).to be == 1 # the deployment has 1 replicas defined

          pods.each{ |pod|
            expect(pod['metadata']['name']).to match(/moviedb-frontend-[-a-z0-9]+/)
            expect(pod['status']['phase']).to eq('Running')
            expect(pod['status']['containerStatuses'].count).to be >= 1
            pod['status']['containerStatuses'].each{ |container|
              expect(container['started']).to eq(true)
            }
          }
        }
        wait_until(120,15) {
          pods = @kubectl.get_pods_by_label("app=jcio,app.kubernetes.io/component=moviedb-backend", 'jcio')
          expect(pods).to_not be_nil
          expect(pods.count).to be == 1 # the deployment has 1 replicas defined

          pods.each{ |pod|
            expect(pod['metadata']['name']).to match(/moviedb-backend-[-a-z0-9]+/)
            expect(pod['status']['phase']).to eq('Running')
            expect(pod['status']['containerStatuses'].count).to be >= 1
            pod['status']['containerStatuses'].each{ |container|
              expect(container['started']).to eq(true)
            }
          }
        }
      end

      if Config.ingress_enabled
        it 'has ingresses' do
          ingresses = @kubectl.get_ingresses('jcio')
          expect(ingresses).to_not be_nil

          ingresses.map! { |ingress| ingress['metadata']['name'] }
          expect(ingresses).to include('jcio-frontend', 'moviedb')
        end

        if Config.lets_encrypt_enabled
          it 'has valid certificates' do
            wait_until(120,15) {
              certificates = @kubectl.get_certificates('jcio')
              expect(certificates).to_not be_nil
              expect(certificates.count).to be >= 2

              ['jcio-tls','moviedb-tls'].each { |cert|
                expect(certificates.any?{ |c| c['metadata']['name'] == cert }).to eq(true)
                certificate = certificates.select{ |c| c['metadata']['name'] == cert }.first

                expect(certificate['spec']).to_not be_nil
                expect(certificate['spec']['dnsNames']).to_not be_nil
                if cert == 'jcio-tls'
                  expect(certificate['spec']['dnsNames'].count).to eq(2)
                  expect(certificate['spec']['dnsNames']).to include("www.#{Config.domain}", "#{Config.domain}")
                end
                if cert == 'moviedb-tls'
                  expect(certificate['spec']['dnsNames'].count).to eq(3)
                  expect(certificate['spec']['dnsNames']).to include("moviedb.#{Config.domain}", "moviedb-frontend.#{Config.domain}", "moviedb-backend.#{Config.domain}")
                end

                expect(certificate['status']).to_not be_nil
                expect(certificate['status']['conditions']).to_not be_nil
                expect(certificate['status']['conditions'].count).to eq(1)
                expect(certificate['status']['conditions'][0]['type']).to eq('Ready')
                expect(certificate['status']['conditions'][0]['status']).to eq('True')

                expect(Time.parse(certificate['status']['notAfter']) > (Time.now + 60*60*24*5)).to eq(true)
                expect(Time.parse(certificate['status']['notAfter']) < (Time.now + 60*60*24*180)).to eq(true)
                expect(Time.parse(certificate['status']['notBefore']) < Time.now).to eq(true)
              }
            }
          end

          it "can be https queried via domain [www.#{Config.domain}]" do
            wait_until(60,15) {
              response = https_get("https://www.#{Config.domain}")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('text/html')
              expect(response.headers[:strict_transport_security]).to include('max-age','includeSubDomains')
              expect(response.body).to include('<meta name="description" content="jamesclonk.io">')
              expect(response.body).to include('<title>jamesclonk.io</title>')
              expect(response.body).to include('<a href="https://blog.jamesclonk.io">')
            }
          end

          it "serves static/public resources correctly" do
            wait_until(60,10) {
              response = https_get("https://#{Config.domain}/css/jcio.css")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('text/css')
              expect(response.headers[:strict_transport_security]).to include('max-age','includeSubDomains')
              expect(response.body).to include('img.coa {', 'img.welcome-picture {', 'div.quotes {', '/* #Media Queries')

              response = https_get("https://#{Config.domain}/favicon.ico")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('image/vnd.microsoft.icon')

              response = https_get("https://www.#{Config.domain}/images/jamesclonk_coa.png")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('image/png')

              response = https_get("https://#{Config.domain}/images/goty/skyrim.jpg")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('image/jpeg')

              response = https_get("https://www.#{Config.domain}/static/Movies")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('text/html')
              expect(response.headers[:strict_transport_security]).to include('max-age','includeSubDomains')
              expect(response.body).to include('Hier meine krassen Filmchen!', 'The Return of the Gummienten Mann')
              expect(response.body).to include('Wer sie sehen will, muss mir eine Nachricht schicken.')

              response = https_get("https://#{Config.domain}/static/Quake")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('text/html')
              expect(response.headers[:strict_transport_security]).to include('max-age','includeSubDomains')
              expect(response.body).to include('Quake 3 Challenge ProMode Arena', '\exec speed.cfg')

              response = https_get("https://#{Config.domain}/goty/2011")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('text/html')
              expect(response.headers[:strict_transport_security]).to include('max-age','includeSubDomains')
              expect(response.body).to include('Year of 2011 Awards')
              expect(response.body).to include('The Elder Scrolls V: Skyrim')
              expect(response.body).to include('DOVAHKIIN DOVAHKIIN', 'NAAL OK ZIN LOS VAHRIIN')
            }
          end

          it "shows RSS feeds on [#{Config.domain}/news]" do
            wait_until(60,10) {
              response = https_get("https://#{Config.domain}/news")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('text/html')
              expect(response.body).to include('<a href="https://news.ycombinator.com/item?id=', 'Hacker News')
              expect(response.body).to include('<a href="https://www.heise.de/news/', 'heise online News')
              expect(response.body).to include('<a href="https://www.reddit.com/r/technology/comments/', '/r/Technology')
              expect(response.body).to include('<a href="https://arstechnica.com/', 'Ars Technica')
            }
          end

          it "has a working movie database on [moviedb.#{Config.domain}]" do
            wait_until(60,15) {
              response = https_get("https://moviedb.#{Config.domain}")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('text/html')
              expect(response.body).to include('<title>jamesclonk.io - Movie Database</title>')
              expect(response.body).to include('<a href="/movies?sort=title&amp;by=asc">by Name</a>')
              expect(response.body).to include('<a href="/movies?query=char&amp;value=z&amp;sort=title&amp;by=asc">Z</a>')
              expect(response.body).to include('<span class="nav-name">Statistics</span>')
              expect(response.body).to include('<td><a class="no-underline" href="/movie/243">Alien vs. Predator</a></td>')
              expect(response.body).to include('<td><a class="no-underline" href="/movie/275">Auch die Engel essen Bohnen</a></td>')
              expect(response.body).to include('<a class="no-underline score" href="/movies?query=score&value=5&sort=title&by=asc"><strong>★★★★★</strong></a>')
              expect(response.body).to include('<a class="no-underline" href="/movies?query=year&value=2008"><span class="label label-default">2008</span></a>')
              expect(response.body).to include('<a class="no-underline score" href="/movies?query=score&value=5&sort=title&by=asc"><strong>★★★★★</strong></a>')
            }
            wait_until(60,15) {
              response = https_get("https://moviedb.#{Config.domain}/movies?query=score&value=5&sort=title&by=asc")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('text/html')
              expect(response.body).to include('<td><a class="no-underline" href="/movie/72">Cowboy Bebop - The Movie</a></td>')
              expect(response.body).to include('<td><a class="no-underline" href="/movie/50">Pulp Fiction</a></td>')

              response = https_get("https://moviedb.#{Config.domain}/movies?query=char&value=z&sort=title&by=asc")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('text/html')
              expect(response.body).to include('<td><a class="no-underline" href="/movie/1010">Zatôichi</a></td>')
            }
            wait_until(60,15) {
              response = https_get("https://moviedb.#{Config.domain}/movie/148")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('text/html')
              expect(response.body).to include('<title>jamesclonk.io - Movie Database - Zwei ausser Rand und Band</title>')
              expect(response.body).to include('<p class="list-group-item-text">I due superpiedi quasi piatti</p>')
              expect(response.body).to include('die beiden Gelegenheitsganoven Wilbur Walsh und Matt Kirby')
            }
            wait_until(60,15) {
              response = https_get("https://moviedb.#{Config.domain}/directors")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('text/html')
              expect(response.body).to include('<div class="col-md-3 col-sm-4"><a class="no-underline" href="/person/210">Christopher Nolan</a></div>')

              response = https_get("https://moviedb.#{Config.domain}/person/210")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('text/html')
              expect(response.body).to include('<title>jamesclonk.io - Movie Database - Christopher Nolan</title>')
              expect(response.body).to include('<td><a class="no-underline" href="/movie/399">The Dark Knight</a></td>')
            }
          end
        end
      end
    end
  end
end
