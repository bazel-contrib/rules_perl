# Copyright 2022 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http:#www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;
use Test::More;

my $file = $ENV{'COVERAGE_INDEX_HTML'};
ok(defined $file, 'COVERAGE_INDEX_HTML is set');

if (defined $file) {
    open my $fh, '<', $file or die "Could not open file '$file': $!\n";
    my $content = do { local $/; <$fh> };
    close $fh;

    like($content, qr{<title>LCOV - coverage\.dat</title>}, 'Expected <title> tag found');
}

done_testing;
