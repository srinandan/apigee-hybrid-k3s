#!/bin/sh
# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


snap install kubectl --classic
export PATH=/snap/core18/1885/usr/bin:$PATH

cd ~

curl -L https://istio.io/downloadIstio | sh -

cp istio-1.7.3/bin/istioctl /usr/local/bin

export VERSION=1.3.3
curl -LO https://storage.googleapis.com/apigee-public/apigee-hybrid-setup/$VERSION/apigeectl_linux_64.tar.gz && gunzip apigeectl_linux_64.tar.gz && tar -xvf apigeectl_linux_64.tar && cp apigeectl_1.3.3-4cbb601_linux_64/apigeectl /usr/local/bin


